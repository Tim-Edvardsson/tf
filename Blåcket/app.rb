require 'sinatra'
require 'slim'
require 'sqlite3'
require 'bcrypt'
require 'sinatra/reloader'
require_relative './model.rb'

#Jani7
#ER
#Loggbok
#Bilder

enable :sessions

include Model

# Opens a connection to an SQLite database.
# @param [String] path the path to the database file
# @return [SQLite3::Database] a connection to the database
def connect_to_db(path)
  db = SQLite3::Database.new(path)
  db.results_as_hash = true
  return db
end

# Updates the time of the last comment to the current time.
# @return [Time] the most recent time
def updatera_tiden
  session[:last_comment_time] = Time.now
end

# Checks if more than 3 seconds have passed since the last comment.
# @return [Boolean] true if more than 3 seconds have passed since the last comment, otherwise false
def kolla_tiden
  if session[:last_comment_time].nil?
    return true
  else
    return Time.now - session[:last_comment_time] > 3
  end
end

# Returns the most recent time a user interacted with the system.
# @return [Time] the most recent time
def senaste_tiden
  session[:senaste_tiden] ||= Time.now - 61
end

# Checks if the time has expired.
# @return [Boolean] true if more than 5 seconds have passed since the last interaction, otherwise false
def tiden_expired?
  Time.now - senaste_tiden > 5
end

# Returns the timestamp of the most recent registration.
# @return [Time] the timestamp of the most recent registration
def senaste_reg
  session[:senaste_reg] ||= Time.now - 61
end

# Checks if the registration time has expired since last attempt.
# @return [Boolean] true if more than 5 seconds have passed since the last registration, otherwise false
def reg_expired?
  Time.now - senaste_reg > 5
end

# Updates the timestamp of the last advertisement.
# @return [Time] the most recent time
def uppdatera_senaste_annons_time
  session[:senaste_annons_time] = Time.now
end

# Checks if the time since last advertisement has expired.
# @return [Boolean] true if more than 5 seconds have passed since the last advertisement, otherwise false
def senaste_annons_expired?
  if session[:senaste_annons_time].nil?
    return true
  else
    return Time.now - session[:senaste_annons_time] > 5
  end
end

# Checks if the user advertisement ID matches the user ID aswell if the advertisement ID is nil, and redirects to ('/') if true
# @param [Integer] user_annons_id the user advertisement ID
# @param [Integer] user_id the user ID
def user_annons_id(user_annons_id, user_id)
  if user_annons_id.nil? || user_id != user_annons_id[0]
    redirect('/')
  end
end

# This method checks if the session ID is nil and the user ain't logged in. If it is, the user is redirected to the homepage ('/')
def require_login
  #Denna kollar om session id är tomt
  if session[:id].nil?
    redirect('/')
  end
end

# Route for handling GET requests to the landing page ("/").
# If a session ID exists, the user is redirected to the account page ("/konto").
get('/') do
  if session[:id]
    redirect('/konto')
  else
    slim(:start)
  end
end

# Route that creates a new user and redirects to ('/') if successful
# @param [String] :username The username provided in the form.
# @param [String] :password The password provided in the form.
# @param [String] :password_confirm The password confirmation provided in the form.
# @see register_user
post('/users/new') do
  username = params[:username]
  password = params[:password]
  password_confirm = params[:password_confirm]
  register_user(username, password, password_confirm)
  redirect('/')
end

# Route that displays the login page
get('/users/login') do
  slim(:"users/login")
end

# Route that handles the login information logs in the user
# @param [String] :username The username provided in the form.
# @param [String] :password The password provided in the form.
# @see user_login
post('/users/login') do
  username = params[:username]
  password = params[:password]
  user_login(username,password)
end

# Route that access and redirects to the users account page.
# @see konto
get('/konto') do
  user_id = session[:id].to_i
  konto(user_id)
end

# Route that clears the session and logsout the user as well as redirects to the landing page ('/')
get('/logout') do
  session.clear
  redirect('/')
end

# Route that goes to the advertisements page.
# @see annonser
get('/annonser') do
  annonser()
end

# Route that handles the filtering of the advertisements.
# @param [String] :genre The selected genre for filtering advertisements.
# @see annonser_filter
post('/annonser/filter') do
  vald_genre = params[:genre]
  annonser_filter(vald_genre)
end

# Route to search and filter the advertisements.
# @param [String] :query The search query for searching advertisements.
# @see annonser_search
get('/annonser/search') do
  query = params[:query]
  annonser_search(query)
end

# Route that goes to the page to create new advertisements.
# @see annonser_new
get('/annonser/new') do
  user_id = session[:id].to_i
  annonser_new(user_id)
end

# Route that creates a new advertisement and redirects back to the users page.
# @param [String] :content The content of the advertisement provided in the form.
# @param [String] :info Additional information about the advertisement provided in the form.
# @param [String] :pris The price of the advertisement provided in the form.
# @param [Tempfile] :img The image file for the advertisement provided in the form.
# @param [String] :genre The primary genre of the advertisement provided in the form.
# @param [String] :genre2 The secondary genre of the advertisement provided in the form.
# @see annonser_new_post
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

#Grammar
# Route that accesses the user's advertisements' information.
# @param [Integer] :user_id The ID of the user.
# @param [Integer] :id The ID of the user advertisment.
# @see user_id
get('/user/:id') do
  user_id = session[:id].to_i
  id = params[:id].to_i
  user_id(user_id, id)
end

# Route that access the information of an advertisement from the advertisment page
# @param [Integer] :user_id The ID of the user.
# @param [Integer] :id The ID of the user advertisment.
# @see annons_id
get('/annons/:id') do
  user_id = session[:id].to_i
  id = params[:id].to_i
  annons_id(user_id, id)
end

# Route that create a new comment.
# @param [String] :comment The content of the comment in the form.
# @param [Integer] :user_id The ID of the current user.
# @param [Integer] :annons_id The ID of the advertisement to which the comment is posted.
# @see comment_new
post('/comment/new') do
  comment = params[:comment]
  user_id = session[:id].to_i
  annons_id = params[:annons_id].to_i
  comment_new(comment, user_id, annons_id)
end

# Route that lets the owner or an admin delete a comment.
# @param [Integer] :kommentar_id The ID of the comment to be deleted.
# @param [Integer] :user_id The ID of the current user.
# @param [Integer] annons_id The ID of the current advertisement.
# @see comment_delete
post('/comment/:kommentar_id/delete') do
  kommentar_id = params[:kommentar_id].to_i
  user_id = session[:id].to_i
  annons_id = session[:current_annons_id].to_i
  comment_delete(kommentar_id, user_id, annons_id)
end

# Route that lets an admin delete an advertisement and the then redirects to ('/annonser').
# @param [Integer] :id The ID of the advertisement to be deleted.
# @see delete_entity
post('/annons/:id/delete') do
  delete_entity(params[:id], '/annonser')
end

# Route that lets a usere delete its own advertisement and the then redirects to ('/konto').
# @param [Integer] :id The ID of the user account to be deleted.
# @see delete_entity
post('/user/:id/delete') do
  delete_entity(params[:id], '/konto')
end

# Route that displays and allows a user to access and edit an advertisment.
# @param [Integer] user_id The ID of the current user.
# @param [Integer] :id The ID of the advertisment that is being edited.
# @see user_edit
get('/user/:id/edit') do
  user_id = session[:id].to_i
  id = params[:id].to_i
  user_edit(user_id, id)
end

# Route that updates the information of an advertisment.
# @param [Integer] :id The ID of the user whose profile is being updated.
# @param [String] :content The content to be updated in the user profile.
# @param [String] :info The additional information to be updated in the user profile.
# @param [Integer] :pris The price to be updated in the user profile.
# @param [String] :genre The genre to be updated in the user profile.
# @see user_update
post('/user/:id/update') do
  id = params[:id].to_i
  content = params[:content]
  info = params[:info]
  pris = params[:pris].to_i
  genre = params[:genre]
  user_update(id, content, info, pris, genre)
end
