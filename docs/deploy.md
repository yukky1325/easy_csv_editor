# 本番デプロイ手順（VPS 直接インストール）

Ubuntu 22.04 / 24.04 の VPS に、**Docker を使わず** Rails を直接インストールして公開する手順です。

## 構成イメージ

```
インターネット
    ↓ 443 (HTTPS)
Nginx（リバースプロキシ）
    ↓ 127.0.0.1:3000
Puma（Rails / easy_csv_editor）
    ↓
SQLite（storage/production.sqlite3）
tmp/csv_tool/（アップロード CSV の一時保存）
```

## 前提

| 項目 | 推奨 |
|------|------|
| VPS | ConoHa VPS / さくらのVPS など（1GB メモリ以上） |
| OS | Ubuntu 22.04 LTS または 24.04 LTS |
| ドメイン | 任意（HTTPS 用。IP のみでも可だが非推奨） |
| DNS | ドメインの A レコードを VPS の IP に向ける |

以降、ドメインを `example.com`、デプロイ用ユーザー名を `deploy`、アプリ配置先を `/var/www/easy_csv_editor` とします。

---

## 1. サーバー初期設定

VPS に SSH で root ログインし、一般ユーザーを作成します。

```bash
adduser deploy
usermod -aG sudo deploy
rsync --archive --chown=deploy:deploy ~/.ssh /home/deploy
```

以降は `deploy` ユーザーで作業します。

```bash
sudo apt update
sudo apt upgrade -y
sudo apt install -y build-essential git curl libssl-dev libreadline-dev \
  zlib1g-dev libsqlite3-dev libyaml-dev nginx ufw
sudo ufw allow OpenSSH
sudo ufw allow 'Nginx Full'
sudo ufw enable
```

---

## 2. Ruby 3.3 のインストール（rbenv）

```bash
curl -fsSL https://github.com/rbenv/rbenv-installer/raw/HEAD/bin/rbenv-installer | bash
```

シェルの設定ファイル（`~/.bashrc`）の末尾に以下を追加し、再ログインします。

```bash
export PATH="$HOME/.rbenv/bin:$PATH"
eval "$(rbenv init - bash)"
```

```bash
rbenv install 3.3.6
rbenv global 3.3.6
ruby -v   # => ruby 3.3.6
gem install bundler
```

---

## 3. アプリケーションの配置

```bash
sudo mkdir -p /var/www
sudo chown deploy:deploy /var/www
cd /var/www

git clone https://github.com/yukky1325/easy_csv_editor.git
cd easy_csv_editor
```

本番用の環境変数ファイルを作成します（**Git には含めない**）。

```bash
nano /var/www/easy_csv_editor/.env.production
```

```bash
RAILS_ENV=production
RAILS_MASTER_KEY=（ローカルの config/master.key の内容を貼り付け）
SECRET_KEY_BASE=（bin/rails secret で生成した値。未設定時は credentials に依存）
PORT=3000
RAILS_LOG_LEVEL=info

# PostHog（任意・本番分析用）
POSTHOG_API_KEY=phc_xxxxxxxx
POSTHOG_HOST=https://us.i.posthog.com
```

```bash
chmod 600 /var/www/easy_csv_editor/.env.production
```

`RAILS_MASTER_KEY` の確認（ローカル開発環境で）:

```bash
cat config/master.key
```

`SECRET_KEY_BASE` の生成（ローカルまたはサーバーで）:

```bash
bin/rails secret
```

---

## 4. 依存関係のインストールとビルド

```bash
cd /var/www/easy_csv_editor
set -a && source .env.production && set +a

bundle config set --local deployment 'true'
bundle config set --local without 'development test'
bundle install

bin/rails db:prepare
bin/rails assets:precompile
```

動作確認（一時的に起動）:

```bash
bin/rails server -e production -b 127.0.0.1 -p 3000
```

別ターミナルから `curl -I http://127.0.0.1:3000/up` で `200` が返れば OK です。確認後 `Ctrl+C` で停止します。

---

## 5. 許可するホスト名の設定

`config/environments/production.rb` の `config.hosts` を編集し、自分のドメインを許可します。

```ruby
config.hosts = [
  "example.com",
  "www.example.com"
]
```

IP のみで試す場合は一時的にコメントアウトしたままでも動きますが、本番では必ずドメインを設定してください。

変更後は再デプロイ（後述）で反映します。

---

## 6. systemd で Puma を常時起動

```bash
sudo nano /etc/systemd/system/easy_csv_editor.service
```

```ini
[Unit]
Description=easy_csv_editor (Rails Puma)
After=network.target

[Service]
Type=simple
User=deploy
WorkingDirectory=/var/www/easy_csv_editor
EnvironmentFile=/var/www/easy_csv_editor/.env.production
Environment=RAILS_ENV=production
ExecStart=/home/deploy/.rbenv/shims/bundle exec puma -C config/puma.rb
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
```

`ExecStart` の `bundle` パスは `which bundle` の結果に合わせてください。

```bash
sudo systemctl daemon-reload
sudo systemctl enable easy_csv_editor
sudo systemctl start easy_csv_editor
sudo systemctl status easy_csv_editor
```

---

## 7. Nginx のリバースプロキシ

```bash
sudo nano /etc/nginx/sites-available/easy_csv_editor
```

```nginx
server {
    listen 80;
    server_name example.com www.example.com;

    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_read_timeout 300;
        client_max_body_size 6M;
    }
}
```

`client_max_body_size` はアップロード上限（5MB）より少し大きくしています。

```bash
sudo ln -s /etc/nginx/sites-available/easy_csv_editor /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
```

---

## 8. HTTPS（Let's Encrypt）

```bash
sudo apt install -y certbot python3-certbot-nginx
sudo certbot --nginx -d example.com -d www.example.com
```

証明書の自動更新は certbot が設定します。Rails 側は `config.force_ssl = true` が有効なため、HTTPS リダイレクトが動作します。

---

## 9. 一時ファイルの定期削除（cron）

24 時間以上経過した `tmp/csv_tool/` のファイルを毎日削除します。

```bash
crontab -e
```

```cron
0 4 * * * cd /var/www/easy_csv_editor && set -a && . ./.env.production && set +a && /home/deploy/.rbenv/shims/bundle exec rails csv_tool:cleanup >> /var/www/easy_csv_editor/log/cleanup.log 2>&1
```

---

## 10. デプロイ更新手順

コードを更新したときはサーバーで以下を実行します。

```bash
cd /var/www/easy_csv_editor
git pull origin main
set -a && source .env.production && set +a

bundle install
bin/rails db:migrate
bin/rails assets:precompile

sudo systemctl restart easy_csv_editor
```

---

## 11. 動作確認チェックリスト

- [ ] `https://example.com` でアップロード画面が開く
- [ ] CSV をアップロード → プレビュー → 加工 → ダウンロードまで完了する
- [ ] `https://example.com/up` が `200` を返す
- [ ] PostHog にイベントが届く（設定時）
- [ ] `tmp/csv_tool/` にファイルが溜まりすぎない（cron 確認）

---

## トラブルシューティング

### 502 Bad Gateway

```bash
sudo systemctl status easy_csv_editor
journalctl -u easy_csv_editor -n 50 --no-pager
```

Puma が起動していない、または `.env.production` の `RAILS_MASTER_KEY` が誤っている可能性があります。

### Blocked hosts

`config/environments/production.rb` の `config.hosts` にアクセス中のドメインを追加してください。

### アップロードが失敗する

Nginx の `client_max_body_size` を確認してください（手順 7）。

### PostHog にイベントが来ない

```bash
grep POSTHOG /var/www/easy_csv_editor/.env.production
sudo systemctl restart easy_csv_editor
```

本番では `POSTHOG_API_KEY` が設定されていれば自動で有効になります。

---

## セキュリティ上の注意

- `config/master.key` と `.env.production` は **Git にコミットしない**
- VPS の SSH は鍵認証のみにし、root 直ログインを無効化することを推奨
- 本アプリはログイン機能がないため、公開 URL を知っている誰でも利用できます。社内限定にしたい場合は Nginx で Basic 認証や IP 制限を検討してください

---

## Docker で本番運用したい場合

開発環境と同じく Docker Compose でも運用できますが、Ver.1 では **VPS 直接インストール**を推奨しています。Docker 本番用の compose ファイルが必要な場合は別途追加してください。
