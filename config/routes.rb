Rails.application.routes.draw do
  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/*
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest

  root "csv_files#new"

  resources :csv_files, only: [], param: :token do
    member do
      get :preview
      post :process, action: :run
      get :result
      get :download
    end
  end

  post "csv_files", to: "csv_files#create", as: :csv_files
end
