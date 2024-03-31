require 'sinatra'
require 'slim'
require 'sqlite3'
require 'bcrypt'
require 'sinatra/reloader'
#require 'sinatra/flash'

#Jani5
#ER
#Loggbok
#Yardoc
#MVC
#_______________________________________________________________________________________________________________________

enable :sessions

def connect_to_db(path)
  #Bara en funktion för att snabbt kunna connecta till databasen
  db = SQLite3::Database.new(path)
  db.results_as_hash = true
  return db
end

def require_login
  #Denna kollar om session id är tomt
  if session[:id].nil?
    redirect('/')
  end
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

def delete_entity(id, redirect_path)
  id = id.to_i
  db = SQLite3::Database.new("db/todo.db")
  kommentar_ids = db.execute("SELECT kommentar_id FROM kommentarer WHERE annons_id = ?", id).flatten
  kommentar_ids.each do |kommentar_id|
    db.execute("DELETE FROM kommentarer WHERE kommentar_id = ?", kommentar_id)
  end
  db.execute("DELETE FROM annonser WHERE id = ?", id)
  redirect(redirect_path)
end

get('/') do
  #Denna kollar om någon är inloggad eller om de ska till start sidan
  if session[:id]
    redirect('/konto')
  else
    slim(:start)
  end
end

post('/users/new') do
  #Denna kollar om det gått tilräckligt lång tid innan den skapar en ny med reg form. Den har också felhantering med om det redan finns en user med det namnet, fel lösen eller om username är tomt
  if reg_expired?
    session[:senaste_reg] = Time.now
  else
    session[:error] = "För snabbt! Försök igen om en stund."
    redirect('/')
  end
  username = params[:username]
  password = params[:password]
  password_confirm = params[:password_confirm]
  db = SQLite3::Database.new('db/todo.db')
  existing_user = db.execute("SELECT * FROM users WHERE username = ?", username).first
  if existing_user
    session[:error] = "Användarnamnet #{username} är redan taget."
    redirect('/')
  elsif password != password_confirm
    session[:error] = "Lösenordet matchade inte."
    redirect('/')
  elsif username.nil? || username.strip.empty?
    session[:error] = "Användarnamn får inte vara tomt."
    redirect('/')
  else
    password_digest = BCrypt::Password.create(password)
    db.execute("INSERT INTO users (username, pwdigest) VALUES (?, ?)", username, password_digest)
    redirect('/')
  end
end

get('/login') do
  #Denna skickar dig till login sidan
    slim(:login)
end

post('/login') do
  #Denna kolla om tiden har expired. Sedan tar den din input och loggar in dig. Den har också felhantering. Den skickar dig till ditt konto om rätt annars felmeddelande
  if tiden_expired?
    session[:senaste_tiden] = Time.now
  else
    session[:error] = "För snabbt! Försök igen om en stund."
    redirect('/login')
  end
  username = params[:username]
  password = params[:password]
  db = connect_to_db('db/todo.db')
  result = db.execute("SELECT * FROM users WHERE username = ?", username).first
  pwdigest = result["pwdigest"] if result
  if result && BCrypt::Password.new(pwdigest) == password
    session[:id] = result["id"]
    redirect ('/konto')
  else
    slim(:login,locals:{error: "Fel användarnamn eller lösenord"})
  end
end

get('/konto') do
  #Denna kolla om någon faktiskt är inloggad, den visar ditt konto med information och annat. Den skriver bara namnet om det finns ett
  require_login
  user_id = session[:id].to_i
  db = connect_to_db('db/todo.db')
  user_info = db.execute("SELECT username FROM users WHERE id = ?", user_id).first
  username = user_info["username"] if user_info
  result = db.execute("SELECT * FROM annonser WHERE user_id = ?", user_id)
  slim(:"users/index", locals: {user:result,username:username})
end

get ('/logout') do
  #Denna rensar session om du loggar ut
  session.clear
  redirect('/')
end

# get('/annonser') do
#   db = connect_to_db('db/todo.db')
#   annonser = db.execute("SELECT annonser.*, users.username AS username FROM annonser INNER JOIN users ON annonser.user_id = users.id")
#   slim(:"/annonser/index", locals: { annonser: annonser })
# end

get('/annonser') do
  db = connect_to_db('db/todo.db')
  annonser = db.execute("SELECT * FROM annonser")
  genres = db.execute("SELECT * FROM genre")
  annonser.each do |annons|
    user_info = db.execute("SELECT username FROM users WHERE id = ?", annons['user_id']).first
    annons['username'] = user_info["username"] if user_info
  end
  slim(:"/annonser/index", locals: { annonser: annonser, genres: genres })
end

post('/annonser/filter') do
  db = connect_to_db('db/todo.db')

  vald_genre = params[:genre]
  if vald_genre == "Alla"
    annonser = db.execute("SELECT * FROM annonser")
  else
    genre_id = db.execute("SELECT id FROM genre WHERE name = ?", vald_genre).first['id']
    annonser = db.execute("SELECT * FROM annonser WHERE id IN (SELECT annons_id FROM genre_annonser WHERE genre_id = ? OR genre_id2 = ?)", genre_id, genre_id)
  end
  genres = db.execute("SELECT * FROM genre")
  annonser.each do |annons|
    user_info = db.execute("SELECT username FROM users WHERE id = ?", annons['user_id']).first
    annons['username'] = user_info["username"] if user_info
  end
  slim(:"/annonser/index", locals: { annonser: annonser, genres: genres })
end

get('/annonser/search') do
  query = params[:query]
  if query && !query.empty?
    db = connect_to_db('db/todo.db')
    genres = db.execute("SELECT * FROM genre")
    db.results_as_hash = true # Ange att resultatet ska returneras som hash för att hantera teckenkodning
    annonser = db.execute("SELECT * FROM annonser WHERE content LIKE ?", "%#{query}%")
    annonser.each do |annon|
      user_info = db.execute("SELECT username FROM users WHERE id = ?", annon['user_id']).first
      annon['username'] = user_info["username"] if user_info
    end
    slim(:"/annonser/index", locals: { annonser: annonser, genres: genres  })
  else
    redirect('/annonser')
  end
end

get('/annonser/new') do
  #Denna låter än skapa nya annonser. Den h'mtar också dit användarnamn
  require_login
  user_id = session[:id].to_i
  db = connect_to_db('db/todo.db')
  genres = db.execute("SELECT * FROM genre")
  user_info = db.execute("SELECT username FROM users WHERE id = ?", user_id).first
  username = user_info["username"] if user_info
  slim(:"/annonser/new",locals:{username:username,genres:genres})
end

post('/annonser/new') do
  # Här skickar den din data för att skapa nya annonser. Den kollar också tiden mellan annonserna samt ifall något är tomt
  content = params[:content]
  info = params[:info]
  pris = params[:pris]
  img = params[:img][:tempfile].read if params[:img]

  if content.nil? || content.strip.empty?
    session[:error] = "Titeln på din vara får inte vara tomt."
    redirect('/konto')
  elsif info.nil? || info.strip.empty?
    session[:error] = "Information om din vara får inte vara tomt."
    redirect('/konto')
  elsif pris.nil? || pris.strip.empty?
    session[:error] = "Priset på din vara får inte vara tomt."
    redirect('/konto')
  elsif img.nil? || img.strip.empty?
    session[:error] = "Du måste ha en bild"
    redirect('/konto')
  end

  if senaste_annons_expired?
    genre_name = params[:genre]
    genre_name2 = params[:genre2]
    session[:senaste_annons_time] = Time.now
    user_id = session[:id].to_i
    db = SQLite3::Database.new("db/todo.db")
    db.execute("INSERT INTO annonser (content, genre, user_id, pris, info, img, genre2) VALUES (?,?,?,?,?,?,?)", content, genre_name, user_id, pris, info, img, genre_name2)
    annons_id = db.last_insert_row_id
    genre_id_result = db.execute("SELECT id FROM genre WHERE name = ?", genre_name).first
    genre_id_result2 = db.execute("SELECT id FROM genre WHERE name = ?", genre_name2).first
    db.execute("INSERT INTO genre_annonser (genre_id, genre_id2, annons_id) VALUES (?, ?, ?)", genre_id_result, genre_id_result2, annons_id)
    redirect('/konto')
  else
    session[:error] = "För snabbt! Försök igen om en stund."
    redirect('/konto')
  end
end

get('/user/:id') do
  #Denna hämtar information om annonsen och dess kommentarer
  user_id = session[:id].to_i
  id = params[:id].to_i
  session[:current_annons_id] = id
  db = connect_to_db('db/todo.db')
  user_annons_id = db.execute("SELECT user_id FROM annonser WHERE id = ?", id).first

  if user_annons_id.nil? || user_id != user_annons_id[0]
    redirect('/')
  end

  result = db.execute("SELECT * FROM annonser WHERE id = ?", id).first
  user_info = db.execute("SELECT username FROM users WHERE id = ?", result['user_id']).first
  username = user_info["username"] if user_info
  kommentarer = db.execute("SELECT kommentarer.*, users.username AS kommentar_username FROM kommentarer JOIN users ON kommentarer.user_id = users.id WHERE annons_id = ?", id)
  slim(:"annonser/show",locals:{result:result,username:username,kommentarer:kommentarer})
end

get('/annons/:id') do
  #Denna hämtar information om annonsen och dess kommentarer
  user_id = session[:id].to_i
  id = params[:id].to_i
  session[:current_annons_id] = id
  db = connect_to_db('db/todo.db')
  result = db.execute("SELECT * FROM annonser WHERE id = ?", id).first
  user_info = db.execute("SELECT username FROM users WHERE id = ?", result['user_id']).first
  username = user_info["username"] if user_info
  kommentarer = db.execute("SELECT kommentarer.*, users.username AS kommentar_username FROM kommentarer JOIN users ON kommentarer.user_id = users.id WHERE annons_id = ?", id)
  slim(:"annonser/show",locals:{result:result,username:username,kommentarer:kommentarer})
end

post('/comment/new') do
  #I denna kan man skapa nya kommentarer
  comment = params[:comment]
  user_id = session[:id].to_i
  annons_id = params[:annons_id].to_i

  if comment.nil? || comment.strip.empty?
    session[:error] = "Kommentaren får inte vara tom."
    redirect("/annons/#{annons_id}")
  end

  if kolla_tiden
    db = SQLite3::Database.new("db/todo.db")
    db.execute("INSERT INTO kommentarer (comment, user_id, annons_id) VALUES (?, ?, ?)", comment, user_id, annons_id)
    updatera_tiden
    redirect("/annons/#{annons_id}")
  else
    session[:error] = "Du kan inte lägga till en kommentar så snabbt efter din senaste kommentar."
    redirect("/annons/#{annons_id}")
  end
end

post('/comment/:kommentar_id/delete') do
  #Denna gör så att man kan radera kommentarer.
  kommentar_id = params[:kommentar_id].to_i
  user_id = session[:id].to_i
  annons_id = session[:current_annons_id].to_i
  db = SQLite3::Database.new("db/todo.db")
  db.execute("DELETE FROM kommentarer WHERE kommentar_id = ?", kommentar_id)
  redirect("/annons/#{annons_id}")
end

post('/annons/:id/delete') do
  #Denna kallar på en funktion som raderar kommentarer och annonsen
  delete_entity(params[:id], '/annonser')
end

post('/user/:id/delete') do
  #Denna kallar på en funktion som raderar kommentarer och annonsen
  delete_entity(params[:id], '/konto')
end

get('/user/:id/edit') do
  #Detta är en get för att uppdatera annonser från sitt konto
  user_id = session[:id].to_i
  id = params[:id].to_i
  db = connect_to_db('db/todo.db')
  session[:current_annons_id] = id
  user_annons_id = db.execute("SELECT user_id FROM annonser WHERE id = ?", id).first

  if user_annons_id.nil? || user_id != user_annons_id[0]
    redirect('/')
  end

  result = db.execute("SELECT * FROM annonser WHERE id = ?", id).first
  slim(:"/annonser/edit",locals:{result:result})
end

post('/user/:id/update') do
  #Detta är en post för att uppdatera annonser från sitt konto. Här får inget heller vara tomt
  id = params[:id].to_i
  content = params[:content]
  info = params[:info]
  pris = params[:pris].to_i
  genre = params[:genre]

  if content.nil? || content.strip.empty?
    session[:error] = "Titeln på din vara får inte vara tomt."
    redirect('/konto')
  elsif info.nil? || info.strip.empty?
    session[:error] = "Information om din vara får inte vara tomt."
    redirect('/konto')
  elsif pris.nil? || pris.zero?
    session[:error] = "Priset på din vara får inte vara tomt."
    redirect('/konto')
  end

  db = SQLite3::Database.new("db/todo.db")
  if params[:img]
    img = params[:img][:tempfile].read
    db.execute("UPDATE annonser SET content=?, genre=?, pris=?, info=?, img=? WHERE id = ?", content, genre, pris, info, img, id)
  else
    db.execute("UPDATE annonser SET content=?, genre=?, pris=?, info=? WHERE id = ?", content, genre, pris, info, id)
  end
  redirect('/konto')
end
