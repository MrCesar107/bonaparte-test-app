Rails.application.routes.draw do
  devise_for :users, controllers: {
    registrations: "users/registrations"
  }

  if defined?(MissionControl::Jobs::Engine)
    mount MissionControl::Jobs::Engine, at: "/jobs"
  end

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  resources :dashboard, only: %i[index]
  resources :part_stores, only: %i[new create show edit update destroy]
  resources :datasheets, only: %i[create new show] do
    resource :export, only: :show, controller: "datasheets/exports"
    resources :source_rows, only: %i[index], controller: "datasheets/source_rows"
    resource :metrics, only: %i[show], controller: "datasheets/metrics"
    resources :applications, only: %i[index], controller: "datasheets/applications"
    resources :interchanges, only: %i[index], controller: "datasheets/interchanges"
    resources :attributes, only: %i[index], controller: "datasheets/attributes"
    resources :catalog_rows, only: %i[index], controller: "datasheets/catalog_rows"
  end

  # Defines the root path route ("/")
  root "dashboard#index"
end
