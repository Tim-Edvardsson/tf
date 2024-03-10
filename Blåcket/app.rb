require 'sinatra'
require 'slim'
require 'sqlite3'
require 'bcrypt'
require 'sinatra/reloader'

#Jani2
#Flash
# def connect_to_db(path)
# db = SQLite3::Database.new(path)
# db.results_as_hash = true
# return db
# end

# post('/users/') do
# db = connect_to_db('db/todo.db')
#ER
#Loggbok
#Alla - till _
#Filter och Search
#Tar bort en annons, tar bort kommentarerna med hjälp av relationstabellen
#Felhantering med kommentarerna
#Index inkrementering

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
    slim(:login)
end

post('/login') do
  username = params[:username]
  password = params[:password]
  db = SQLite3::Database.new('db/todo.db')
  db.results_as_hash = true
  result = db.execute("SELECT * FROM users WHERE username = ?",username).first
  pwdigest = result["pwdigest"] if result
  if result && BCrypt::Password.new(pwdigest) == password
    session[:id] = result["id"]
    redirect('/konto')
  else
    slim(:login,locals:{error:"Fel användarnamn eller lösenord"})
  end
end

get('/konto') do
  user_id = session[:id].to_i
  db = SQLite3::Database.new('db/todo.db')
  db.results_as_hash = true
  user_info = db.execute("SELECT username FROM users WHERE id = ?", user_id).first
  username = user_info["username"] if user_info
  result = db.execute("SELECT * FROM annonser WHERE user_id = ?", user_id)
  slim(:"users/index", locals: {user:result,username:username})
end

get ('/logout') do
  session.clear
  redirect ('/')
end

get ('/annonser') do
  db = SQLite3::Database.new('db/todo.db')
  db.results_as_hash = true
  annonser = db.execute("SELECT * FROM annonser")
  annonser.each do |annon|
    user_info = db.execute("SELECT username FROM users WHERE id = ?",annon['user_id']).first
    annon['username'] = user_info["username"] if user_info
  end
  slim(:"/annonser/index",locals:{annonser:annonser})
end

get ('/annonser/search') do
  query = params[:query]
  if query && !query.empty?
    db = SQLite3::Database.new('db/todo.db')
    db.results_as_hash = true
    annonser = db.execute("SELECT * FROM annonser WHERE content LIKE ?", "%#{query}%")
    annonser.each do |annon|
      user_info = db.execute("SELECT username FROM users WHERE id = ?", annon['user_id']).first
      annon['username'] = user_info["username"] if user_info
    end
    slim(:"/annonser/index",locals:{annonser:annonser})
  else
    redirect('/annonser')
  end
end

get('/user/:id') do
  user_id = session[:id].to_i
  id = params[:id].to_i
  session[:current_annons_id] = id
  db = SQLite3::Database.new("db/todo.db")
  db.results_as_hash = true
  user_info = db.execute("SELECT username FROM users WHERE id = ?", user_id).first
  username = user_info["username"] if user_info
  result = db.execute("SELECT * FROM annonser WHERE id = ?",id).first
  annons_kommentarer = db.execute("SELECT * FROM annons_kommentarer WHERE annons_id = ?", id)
  kommentarer = []
  annons_kommentarer.each do |row|
    kommentar_id = row['kommentar_id']
    kommentar = db.execute("SELECT kommentarer.*, users.username AS kommentar_username FROM kommentarer JOIN users ON kommentarer.user_id = users.id WHERE kommentar_id = ?", kommentar_id).first
    kommentarer << kommentar if kommentar
  end
  slim(:"annonser/show",locals:{result:result,username:username,kommentarer:kommentarer })
end

get('/annonser/new') do
  user_id = session[:id].to_i
  db = SQLite3::Database.new('db/todo.db')
  db.results_as_hash = true
  user_info = db.execute("SELECT username FROM users WHERE id = ?", user_id).first
  username = user_info["username"] if user_info
  slim(:"/annonser/new",locals:{username:username})
end

post('/annonser/new') do
  content = params[:content]
  info = params[:info]
  pris = params[:pris]
  genre = params[:genre]
  user_id = session[:id].to_i
  img = params[:img][:tempfile].read if params[:img]
  db = SQLite3::Database.new("db/todo.db")
  db.execute("INSERT INTO annonser (content, genre, user_id, pris, info, img) VALUES (?,?,?,?,?,?)",content, genre, user_id, pris, info, img)
  redirect('/konto')
end

get('/annons/:id') do
  user_id = session[:id].to_i
  id = params[:id].to_i
  session[:current_annons_id] = id
  db = SQLite3::Database.new("db/todo.db")
  db.results_as_hash = true
  result = db.execute("SELECT * FROM annonser WHERE id = ?", id).first
  user_info = db.execute("SELECT username FROM users WHERE id = ?", result['user_id']).first
  username = user_info["username"] if user_info
  annons_kommentarer = db.execute("SELECT * FROM annons_kommentarer WHERE annons_id = ?", id)
  kommentarer = []
  annons_kommentarer.each do |row|
    kommentar_id = row['kommentar_id']
    kommentar = db.execute("SELECT kommentarer.*, users.username AS kommentar_username FROM kommentarer JOIN users ON kommentarer.user_id = users.id WHERE kommentar_id = ?", kommentar_id).first
    kommentarer << kommentar if kommentar
  end
  slim(:"annonser/show",locals:{result:result,username:username,kommentarer:kommentarer})
end

post('/comment/new') do
  comment = params[:comment]
  user_id = session[:id].to_i
  annons_id = session[:current_annons_id].to_i
  db = SQLite3::Database.new("db/todo.db")
  db.execute("INSERT INTO kommentarer (comment, user_id) VALUES (?, ?)", comment, user_id)
  kommentar_id = db.last_insert_row_id
  db.execute("INSERT INTO annons_kommentarer (annons_id, kommentar_id) VALUES (?, ?)", annons_id, kommentar_id)
  redirect("/annons/#{annons_id}")
end

post('/comment/:kommentar_id/delete') do
  kommentar_id = params[:kommentar_id].to_i
  user_id = session[:id].to_i
  annons_id = session[:current_annons_id].to_i
  db = SQLite3::Database.new("db/todo.db")
  db.execute("DELETE FROM kommentarer WHERE kommentar_id = ?", kommentar_id)
  db.execute("DELETE FROM annons_kommentarer WHERE kommentar_id = ?", kommentar_id)
  redirect("/annons/#{annons_id}")
end

post('/annons/:id/delete') do
  id = params[:id].to_i
  db = SQLite3::Database.new("db/todo.db")
  kommentar_ids = db.execute("SELECT kommentar_id FROM annons_kommentarer WHERE annons_id = ?", id).flatten #Ta bort
  kommentar_ids.each do |kommentar_id|
    db.execute("DELETE FROM kommentarer WHERE kommentar_id = ?", kommentar_id)
  end
  db.execute("DELETE FROM annons_kommentarer WHERE annons_id = ?", id)
  db.execute("DELETE FROM annonser WHERE id = ?", id)
  redirect('/annonser')
end

#Kan jag sätta ihop dessa?

post('/user/:id/delete') do
  id = params[:id].to_i
  db = SQLite3::Database.new("db/todo.db")
  kommentar_ids = db.execute("SELECT kommentar_id FROM annons_kommentarer WHERE annons_id = ?", id).flatten #Ta bort
  kommentar_ids.each do |kommentar_id|
    db.execute("DELETE FROM kommentarer WHERE kommentar_id = ?", kommentar_id)
  end
  db.execute("DELETE FROM annons_kommentarer WHERE annons_id = ?", id)
  db.execute("DELETE FROM annonser WHERE id = ?",id)
  redirect('/konto')
end

post('/user/:id/update') do
  id = params[:id].to_i
  content = params[:content]
  info = params[:info]
  pris = params[:pris].to_i
  genre = params[:genre]
  db = SQLite3::Database.new("db/todo.db")
  if params[:img]
    img = params[:img][:tempfile].read
    db.execute("UPDATE annonser SET content=?, genre=?, pris=?, info=?, img=? WHERE id = ?", content, genre, pris, info, img, id)
  else
    db.execute("UPDATE annonser SET content=?, genre=?, pris=?, info=? WHERE id = ?", content, genre, pris, info, id)
  end
  redirect('/konto')
end

get('/user/:id/edit') do
  id = params[:id].to_i
  db = SQLite3::Database.new("db/todo.db")
  db.results_as_hash = true
  result = db.execute("SELECT * FROM annonser WHERE id = ?", id).first
  slim(:"/annonser/edit",locals:{result:result})
end
