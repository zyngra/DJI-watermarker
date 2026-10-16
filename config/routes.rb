Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  root "inspections#index"

  resources :inspections, only: [ :index, :show, :new, :create, :destroy ] do
    member do
      post :upload_photos
      get :download_zip
    end
    resources :photos, only: [ :destroy ] do
      member do
        get :download
      end
    end
  end
end
