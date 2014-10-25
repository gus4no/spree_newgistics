Spree::Core::Engine.routes.draw do
  # Add your extension routes here
  namespace :api, defaults: { format: 'json' } do
    post '/newgistics_imports/products' => 'newgistics_imports#products'
    get '/newgistics_imports/status/:job_id' => 'newgistics_imports#status'
  end
end
