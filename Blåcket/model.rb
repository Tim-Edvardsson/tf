require 'sinatra'
require 'slim'
require 'sqlite3'
require 'bcrypt'
require 'sinatra/reloader'
require_relative './model.rb'

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

def register_user(username, password, password_confirm)
  if reg_expired?
    session[:senaste_reg] = Time.now
  else
    session[:error] = "För snabbt! Försök igen om en stund."
    redirect('/')
  end
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
  end
end

def user_login(username, password)
  if tiden_expired?
    session[:senaste_tiden] = Time.now
  else
    session[:error] = "För snabbt! Försök igen om en stund."
    redirect('/users/login')
  end
  db = connect_to_db('db/todo.db')
  result = db.execute("SELECT * FROM users WHERE username = ?", username).first
  pwdigest = result["pwdigest"] if result
  if result && BCrypt::Password.new(pwdigest) == password
    session[:id] = result["id"]
    redirect ('/konto')
  else
    slim(:"/users/login",locals:{error: "Fel användarnamn eller lösenord"})
  end
end

def konto(user_id)
  require_login
  db = connect_to_db('db/todo.db')
  user_info = db.execute("SELECT username FROM users WHERE id = ?", user_id).first
  username = user_info["username"] if user_info
  result = db.execute("SELECT * FROM annonser WHERE user_id = ?", user_id)
  query = params[:query]
  if query && !query.empty?
    result = result.select { |annons| annons['content'].include?(query) }
  end
  slim(:"users/index",locals:{user:result,username:username})
end

def annonser()
  db = connect_to_db('db/todo.db')
  annonser = db.execute("SELECT * FROM annonser")
  genres = db.execute("SELECT * FROM genre")
  annonser.each do |annons|
    user_info = db.execute("SELECT username FROM users WHERE id = ?", annons['user_id']).first
    annons['username'] = user_info["username"] if user_info
  end
  slim(:"/annonser/index", locals: { annonser: annonser, genres: genres })
end

def annonser_filter(vald_genre)
  db = connect_to_db('db/todo.db')
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

def annonser_search(query)
  if query && !query.empty?
    db = connect_to_db('db/todo.db')
    genres = db.execute("SELECT * FROM genre")
    db.results_as_hash = true
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

def annonser_new(user_id)
  require_login
  db = connect_to_db('db/todo.db')
  genres = db.execute("SELECT * FROM genre")
  user_info = db.execute("SELECT username FROM users WHERE id = ?", user_id).first
  username = user_info["username"] if user_info
  slim(:"/annonser/new",locals:{username:username,genres:genres})
end

def annonser_new_post(content, info, pris, img, genre_name, genre_name2, user_id)

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
    session[:senaste_annons_time] = Time.now
    db = connect_to_db('db/todo.db')
    db.execute("INSERT INTO annonser (content, genre, user_id, pris, info, img, genre2) VALUES (?,?,?,?,?,?,?)", content, genre_name, user_id, pris, info, img, genre_name2)
    annons_id = db.last_insert_row_id
    genre_id_result = db.execute("SELECT id FROM genre WHERE name = ?", genre_name).first
    genre_id_result2 = db.execute("SELECT id FROM genre WHERE name = ?", genre_name2).first
    db.execute("INSERT INTO genre_annonser (genre_id, genre_id2, annons_id) VALUES (?, ?, ?)", genre_id_result[0], genre_id_result2[0], annons_id)
    redirect('/konto')
  else
    session[:error] = "För snabbt! Försök igen om en stund."
    redirect('/konto')
  end
end

def user_id(user_id, id)
  session[:current_annons_id] = id
  db = connect_to_db('db/todo.db')
  user_annons_id = db.execute("SELECT user_id FROM annonser WHERE id = ?", id).first
  user_annons_id(user_annons_id, user_id)
  result = db.execute("SELECT * FROM annonser WHERE id = ?", id).first
  user_info = db.execute("SELECT username FROM users WHERE id = ?", result['user_id']).first
  username = user_info["username"] if user_info
  kommentarer = db.execute("SELECT kommentarer.*, users.username AS kommentar_username FROM kommentarer JOIN users ON kommentarer.user_id = users.id WHERE annons_id = ?", id)
  slim(:"annonser/show",locals:{result:result,username:username,kommentarer:kommentarer})
end

def annons_id(user_id, id)
  session[:current_annons_id] = id
  db = connect_to_db('db/todo.db')
  result = db.execute("SELECT * FROM annonser WHERE id = ?", id).first
  user_info = db.execute("SELECT username FROM users WHERE id = ?", result['user_id']).first
  username = user_info["username"] if user_info
  kommentarer = db.execute("SELECT kommentarer.*, users.username AS kommentar_username FROM kommentarer JOIN users ON kommentarer.user_id = users.id WHERE annons_id = ?", id)
  slim(:"annonser/show",locals:{result:result,username:username,kommentarer:kommentarer})
end

def comment_new(comment, user_id, annons_id)
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

def comment_delete(kommentar_id, user_id, annons_id)
  db = SQLite3::Database.new("db/todo.db")
  db.execute("DELETE FROM kommentarer WHERE kommentar_id = ?", kommentar_id)
  redirect("/annons/#{annons_id}")
end

def user_edit(user_id, id)
  db = connect_to_db('db/todo.db')
  session[:current_annons_id] = id
  user_annons_id = db.execute("SELECT user_id FROM annonser WHERE id = ?", id).first
  user_annons_id(user_annons_id, user_id)
  result = db.execute("SELECT * FROM annonser WHERE id = ?", id).first
  slim(:"/annonser/edit",locals:{result:result})
end

def user_update(id, content, info, pris, genre)

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
