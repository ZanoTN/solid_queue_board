# frozen_string_literal: true

SolidQueueBoard::Engine.routes.draw do
  root to: "jobs#index"

  resources :jobs, only: :index do
    member do
      post :retry
      post :discard
    end
    collection do
      post :retry_all
    end
  end

  resources :queues, only: :index, param: :name, constraints: { name: %r{[^/]+} } do
    member do
      post :pause
      post :resume
    end
  end

  resources :recurring_tasks, only: :index, param: :key, constraints: { key: %r{[^/]+} } do
    member do
      post :run
    end
  end

  resources :processes, only: :index
end
