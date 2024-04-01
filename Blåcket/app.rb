require 'sinatra'
require 'slim'
require 'sqlite3'
require 'bcrypt'
require 'sinatra/reloader'
require_relative './model.rb'

#Jani6
#ER
#Loggbok
#Yardoc
#MVC
#Meddelande
#Session
#_______________________________________________________________________________________________________________________

enable :sessions

get('/') do
  if session[:id]
    redirect('/konto')
  else
    slim(:start)
  end
end

post('/users/new') do
  username = params[:username]
  password = params[:password]
  password_confirm = params[:password_confirm]
  register_user(username, password, password_confirm)
  redirect('/')
end

get('/users/login') do
  slim(:"users/login")
end

post('/users/login') do
  username = params[:username]
  password = params[:password]
  user_login(username,password)
end

get('/konto') do
  user_id = session[:id].to_i
  konto(user_id)
end

get('/logout') do
  session.clear
  redirect('/')
end

get('/annonser') do
  annonser()
end

post('/annonser/filter') do
  vald_genre = params[:genre]
  annonser_filter(vald_genre)
end

get('/annonser/search') do
  query = params[:query]
  annonser_search(query)
end

get('/annonser/new') do
  user_id = session[:id].to_i
  annonser_new(user_id)
end

post('/annonser/new') do
  content = params[:content]
  info = params[:info]
  pris = params[:pris]
  img = params[:img][:tempfile].read if params[:img]
  genre_name = params[:genre]
  genre_name2 = params[:genre2]
  user_id = session[:id].to_i
  annonser_new_post(content, info, pris, img, genre_name, genre_name2, user_id)
end

get('/user/:id') do
  user_id = session[:id].to_i
  id = params[:id].to_i
  user_id(user_id, id)
end

get('/annons/:id') do
  user_id = session[:id].to_i
  id = params[:id].to_i
  annons_id(user_id, id)
end

post('/comment/new') do
  comment = params[:comment]
  user_id = session[:id].to_i
  annons_id = params[:annons_id].to_i
  comment_new(comment, user_id, annons_id)
end

post('/comment/:kommentar_id/delete') do
  kommentar_id = params[:kommentar_id].to_i
  user_id = session[:id].to_i
  annons_id = session[:current_annons_id].to_i
  comment_delete(kommentar_id, user_id, annons_id)
end

post('/annons/:id/delete') do
  delete_entity(params[:id], '/annonser')
end

post('/user/:id/delete') do
  delete_entity(params[:id], '/konto')
end

get('/user/:id/edit') do
  user_id = session[:id].to_i
  id = params[:id].to_i
  user_edit(user_id, id)
end

post('/user/:id/update') do
  id = params[:id].to_i
  content = params[:content]
  info = params[:info]
  pris = params[:pris].to_i
  genre = params[:genre]
  user_update(id, content, info, pris, genre)
end
