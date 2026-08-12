# easy_csv_editor

ブラウザ上で CSV ファイルをアップロードし、列の抽出・不要行の削除・文字コード変換を行ったうえで、加工後 CSV をダウンロードできる小規模 Web アプリケーションです。

リポジトリ: https://github.com/yukky1325/easy_csv_editor

## 機能

- CSV ファイルのアップロード（`.csv` のみ、最大 5MB）
- 文字コードの自動判定（UTF-8 / UTF-8（BOM付き） / Windows-31J）
- プレビュー表示（全行）
- 列の複数選択・抽出
- 出力列名の編集
- プレビュー画面でのデータセル編集（Excel風）
- 完全空行の削除
- 指定列が空欄の行の削除
- 出力文字コードの選択（UTF-8 / UTF-8（BOM付き） / Windows-31J）
- 加工結果の概要表示とダウンロード

## 必要条件

- [Docker](https://www.docker.com/)
- [Docker Compose](https://docs.docker.com/compose/)

ホストに Ruby をインストールする必要はありません。開発・テストはすべてコンテナ内で実行します。

## セットアップと起動

リポジトリを取得したディレクトリで、以下を実行します。

```bash
docker compose up --build
```

初回はイメージのビルドと依存関係のインストールに時間がかかります。

起動後、ブラウザで次の URL を開きます。

```
http://localhost:3000
```

バックグラウンドで起動する場合:

```bash
docker compose up -d --build
```

停止する場合:

```bash
docker compose down
```

## 使い方

### 1. CSV をアップロード（画面1）

1. トップ画面で CSV ファイルを選択します。
2. 「アップロード」をクリックします。
3. ファイル検証に成功すると、プレビュー画面へ遷移します。

<!-- スクリーンショット: アップロード画面 -->

### 2. プレビューと加工条件の指定（画面2）

1. アップロードした CSV の内容を確認します。
2. 列見出しと行番号の「出力」で、出力する列・行を選びます。列名行とデータ行のセルは直接編集できます。
3. データ行のセルをクリックして、セルの中身を直接編集できます（Excel風）。編集したセルは黄色で表示されます。
4. 列見出しの **← →** ボタンで列の順序を入れ替えられます（例: 2列目と3列目を交換）。
5. 「行の並べ替え（ソート）」で、出力に選択した列の値を基準にデータ行だけを並べ替えられます（列の位置は変わりません）。
6. 必要に応じて「列名の一括編集」で接頭辞・置換などを適用します（文字列置換は選択列の列名とデータセルの両方に反映されます）。
7. 必要に応じて次の加工オプションを設定します。
   - **完全な空行を削除する**: 元CSVのすべての列が空の行を削除
   - **空欄の行を削除（対象列）**: 指定した列が空欄の行を削除（表の列記号 A〜 で選択）
   - **出力文字コード**: UTF-8 / UTF-8（BOM付き） / Windows-31J
8. 「加工を実行」をクリックします。

<!-- スクリーンショット: プレビュー・加工条件画面 -->

### 3. 加工完了とダウンロード（画面3）

1. 加工結果（行数・列数・文字コードなど）を確認します。
2. 「加工後 CSV をダウンロード」からファイルを取得します。
3. 別のファイルを処理する場合は「最初からやり直す」をクリックします。

<!-- スクリーンショット: 加工完了画面 -->

ダウンロードされるファイル名の形式:

```
{元ファイル名}_converted_{YYYYMMDDHHMMSS}.csv
```

例: `sample_utf8_converted_20260805120000.csv`

## 対応形式

| 項目 | 内容 |
|------|------|
| 拡張子 | `.csv` のみ |
| 入力文字コード | UTF-8 / UTF-8（BOM付き） / Windows-31J |
| 出力文字コード | UTF-8 / UTF-8（BOM付き） / Windows-31J |
| 最大ファイルサイズ | 5MB |
| 改行コード（出力） | CRLF（Excel 互換） |

## テストの実行

```bash
docker compose run --rm web bin/rails test
```

並列実行で問題が出る場合:

```bash
docker compose run --rm web env PARALLEL_WORKERS=1 bin/rails test
```

## 開発用コマンド

| 操作 | コマンド |
|------|---------|
| サーバー起動 | `docker compose up` |
| バックグラウンド起動 | `docker compose up -d` |
| Rails コンソール | `docker compose run --rm web bin/rails console` |
| テスト | `docker compose run --rm web bin/rails test` |
| bundle install | `docker compose run --rm web bundle install` |
| 停止 | `docker compose down` |

## PostHog（利用状況の分析）

ログインなしでも、**匿名のセッション ID** で「どこまで使われたか」を PostHog で確認できます。CSV の中身やファイル名は送信しません。

### セットアップ

1. [PostHog](https://posthog.com/) でプロジェクトを作成し、Project API Key を取得
2. `.env.example` を参考に環境変数を設定

```bash
POSTHOG_API_KEY=phc_xxxxxxxx
POSTHOG_HOST=https://us.i.posthog.com   # EU の場合は https://eu.i.posthog.com
POSTHOG_ENABLED=true
```

`docker-compose.yml` の `environment` に追加するか、本番ホストの環境変数として設定してください。

- **development**: デフォルトでは無効（`POSTHOG_ENABLED=true` で有効化可能）
- **production**: API キーがあれば自動で有効
- **test**: 常に無効

### 送信されるイベント（ファネル）

| イベント | タイミング |
|---------|-----------|
| `$pageview` | 各画面表示（クライアント） |
| `csv_uploaded` | アップロード成功 |
| `csv_upload_failed` | アップロード失敗 |
| `preview_viewed` | プレビュー表示 |
| `csv_processed` | 加工成功 |
| `csv_processing_failed` | 加工バリデーション失敗 |
| `result_viewed` | 完了画面表示 |
| `csv_downloaded` | CSV ダウンロード |

プロパティには行数・列数・文字コードなどの**統計情報のみ**を含め、ファイル名やセル内容は含めません。

PostHog 上では `csv_uploaded` → `preview_viewed` → `csv_processed` → `csv_downloaded` のファネルを作成すると、離脱箇所が把握しやすくなります。

## 一時ファイルとクリーンアップ

アップロード・加工した CSV は `tmp/csv_tool/` に一時保存されます（データベースには保存しません）。ホスト側の `./tmp/csv_tool/` にも反映されます。

24 時間以上経過した一時ファイルは、次の Rake タスクで削除できます。

```bash
docker compose run --rm web bin/rails csv_tool:cleanup
```

本番環境で運用する場合は、cron 等で定期的に実行することを推奨します（Ver.1 では手順の記載のみ）。

## セッション管理

- ブラウザのセッションには token（UUID）とメタ情報のみを保存します。
- CSV のデータ行や加工後の本文はセッションに保存しません。
- 他のユーザーのファイルにアクセスできないよう、リクエスト時にセッション内の token と一致するか検証します。

## セキュリティに関する注意

- **個人情報**: アップロードした CSV は一時ファイルとして扱われます。取り扱いには十分注意してください。
- **CSV Injection**: Excel 等で数式として解釈されうる値（`=` `+` `-` `@` で始まるセル）には、出力時に先頭へ `'` を付与しています。完全な防御ではないため、信頼できない CSV の取り扱いには注意してください。
- **本番デプロイ**: 本アプリは個人開発・学習目的の Ver.1 です。本番向けのデプロイ手順は含みません。

## 技術スタック

| 項目 | 採用 |
|------|------|
| 言語 | Ruby 3.3.x |
| フレームワーク | Ruby on Rails 7.2.x |
| データベース | SQLite（セッション等の最小利用） |
| UI | Bootstrap 5 |
| CSV 処理 | Ruby 標準ライブラリ `CSV` |
| テスト | Minitest |
| 開発環境 | Docker + Docker Compose |

## ドキュメント

- 設計書: [`docs/design.md`](docs/design.md)
- タスク一覧: [`docs/tasks.md`](docs/tasks.md)

## ライセンス

個人開発プロジェクト（Ver.1）。ライセンスはリポジトリ管理者の方針に従います。
