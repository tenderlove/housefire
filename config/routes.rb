Housefire::Application.routes.draw do
  get  '/chat', :to => 'chats#show'
  post '/chat', :to => 'chats#create'
end
