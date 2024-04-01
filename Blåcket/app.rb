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
#Felhantering?
#_______________________________________________________________________________________________________________________

enable :sessions

include Model

#Tror dessa är authorization
def connect_to_db(path)
  #Bara en funktion för att snabbt kunna connecta till databasen
  db = SQLite3::Database.new(path)
  db.results_as_hash = true
  return db
end

def updatera_tiden
  #Denna sätter tiden till det som är nu med time.now
  session[:last_comment_time] = Time.now
end

def kolla_tiden
  #Denna kolla om tiden är tom eller om det har gått längre än 3 sekunder
  if session[:last_comment_time].nil?
    return true
  else
    return Time.now - session[:last_comment_time] > 3
  end
end

def senaste_tiden
  #Denna kollar tiden
  session[:senaste_tiden] ||= Time.now - 61
end

def tiden_expired?
  #Denna kollar om det gått mer än...
  Time.now - senaste_tiden > 5
end

def senaste_reg
  #Denna kollar tiden
  session[:senaste_reg] ||= Time.now - 61
end

def reg_expired?
  #Denna kollar om det gått mer än...
  Time.now - senaste_reg > 5
end

def uppdatera_senaste_annons_time
  #Denna uppdaterar din tid
  session[:senaste_annons_time] = Time.now
end

def senaste_annons_expired?
  #Denna kollar om det har gått tillräckligt lång tid
  if session[:senaste_annons_time].nil?
    return true
  else
    return Time.now - session[:senaste_annons_time] > 5
  end
end

def user_annons_id(user_annons_id, user_id)
  if user_annons_id.nil? || user_id != user_annons_id[0]
    redirect('/')
  end
end

def require_login
  #Denna kollar om session id är tomt
  if session[:id].nil?
    redirect('/')
  end
end
#_______________________________________________________________________________________________________________________

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
