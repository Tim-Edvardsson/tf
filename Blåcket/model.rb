# Module containing methods related to database operations.
module Model

  # Method that deletes an entity advertisement from the database. It also authenticates and checks the user is the owner
  # @param [Integer] id The ID of the entity to be deleted.
  # @param [Integer] user_id The ID of the current user performing the deletion.
  # @param [String] redirect_path The path to redirect to after deletion.
  # @see user_annons_id
  def delete_entity(id, user_id, redirect_path)
    annons_id = id.to_i
    db = SQLite3::Database.new("db/todo.db")
    user_annons_id = db.execute("SELECT user_id FROM annonser WHERE id = ?", annons_id).first
    if user_id != 1
      user_annons_id(user_annons_id, user_id)
    end
    kommentar_ids = db.execute("SELECT kommentar_id FROM kommentarer WHERE annons_id = ?", annons_id).flatten
    kommentar_ids.each do |kommentar_id|
      db.execute("DELETE FROM kommentarer WHERE kommentar_id = ?", kommentar_id)
    end
    db.execute("DELETE FROM annonser WHERE id = ?", annons_id)
    db.execute("DELETE FROM genre_annonser WHERE annons_id = ?", annons_id)
    redirect(redirect_path)
  end

  # Method for registering a new user where it checks the time aswell since last attempt, as well as handles the input if incorrect.
  # @param [String] username The username of the new user.
  # @param [String] password The password of the new user.
  # @param [String] password_confirm The confirmation password of the new user.
  # @see reg_expired?
  # @see $senaste_reg
  # Global variable $error_message stores error messages, which is then displayed
  def register_user(username, password, password_confirm)
    if reg_expired?
      $senaste_reg = Time.now
    else
      $error_message = "För snabbt! Försök igen om en stund."
      redirect('/')
    end

    db = SQLite3::Database.new('db/todo.db')
    existing_user = db.execute("SELECT * FROM users WHERE username = ?", username).first

    if existing_user
      $error_message = "Användarnamnet #{username} är redan taget."
      redirect('/')
    elsif password != password_confirm
      $error_message = "Lösenordet matchade inte."
      redirect('/')
    elsif username.nil? || username.strip.empty?
      $error_message = "Användarnamn får inte vara tomt."
      redirect('/')
    elsif username.length < 6
      $error_message = "Användarnamn måste vara minst sex tecken långt."
      redirect('/')
    elsif password.length < 6
      $error_message = "Lösenordet måste vara minst sex tecken långt."
      redirect('/')
    else
      password_digest = BCrypt::Password.create(password)
      db.execute("INSERT INTO users (username, pwdigest) VALUES (?, ?)", username, password_digest)
    end
  end

  # Method for loggin in a user where it checks the time since last time as well as handls the input if incorrect
  # @param [String] username The username entered by the user.
  # @param [String] password The password entered by the user.
  # @return [Hash] A hash containing the login success status and the user ID if authentication is successful.
  # @see $senaste_tiden
  # @see $error_message
  # @see tiden_expired?
  # @see connect_to_db
  def user_login(username, password)
    if tiden_expired?
      $senaste_tiden = Time.now
    else
      $error_message = "För snabbt! Försök igen om en stund."
      redirect('/users/login')
    end
    db = connect_to_db('db/todo.db')
    result = db.execute("SELECT * FROM users WHERE username = ?", username).first
    pwdigest = result["pwdigest"] if result
    if result && BCrypt::Password.new(result["pwdigest"]) == password
      return{success: true, user_id: result["id"]}
    else
      $error_message = "Fel användarnamn eller lösenord"
      redirect('/users/login')
    end
  end

  # Method for displays the user's acoount page where it checks if someone is logged in.
  # @param [Integer] user_id The ID of the current user.
  # @see connect_to_db
  def konto(user_id)
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

  # Method for dispaying the advertisment page.
  # @see connect_to_db
  def annonser()
    db = connect_to_db('db/todo.db')
    annonser = db.execute("SELECT * FROM annonser")
    genres = db.execute("SELECT * FROM genre")
    annonser.each do |annons|
      user_info = db.execute("SELECT username FROM users WHERE id = ?", annons['user_id']).first
      annons['username'] = user_info["username"] if user_info
    end
    slim(:"/annonser/index",locals:{annonser:annonser,genres:genres})
  end

  # Method for filtering advertisements based on selected genre.
  # @param [String] vald_genre The selected genre for filtering advertisements.
  # @see connect_to_db
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
    slim(:"/annonser/index",locals:{annonser:annonser,genres:genres})
  end

  # Method for searching advertisements based on a query if not emtpy because then it redirects to ('/annonser').
  # @param [String] query The search query for filtering advertisements.
  # @see connect_to_db
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
      slim(:"/annonser/index",locals:{annonser:annonser,genres:genres})
    else
      redirect('/annonser')
    end
  end

  # Method for dispalying the new advertisement page based on who is logged in.
  # @param [Integer] user_id The ID of the current user.
  # @see connect_to_db
  def annonser_new(user_id)
    db = connect_to_db('db/todo.db')
    genres = db.execute("SELECT * FROM genre")
    user_info = db.execute("SELECT username FROM users WHERE id = ?", user_id).first
    username = user_info["username"] if user_info
    slim(:"/annonser/new",locals:{username:username,genres:genres})
  end

  # Method for handling the creation of a new advertisement where it validates and handles the input from the form as well as check the time since last new advertisment.
  # @param [String] content The content/title of the new advertisement.
  # @param [String] info The additional information of the new advertisement.
  # @param [String] pris The price of the new advertisement.
  # @param [Tempfile] img The image file for the new advertisement.
  # @param [String] genre_name The primary genre of the new advertisement.
  # @param [String] genre_name2 The secondary genre of the new advertisement.
  # @param [Integer] user_id The ID of the current user.
  # @see $error_message
  # @see senaste_annons_expired?
  # @see $senaste_annons_time
  # @see connect_to_db
  def annonser_new_post(content, info, pris, img, genre_name, genre_name2, user_id)
    if content.nil? || content.strip.empty?
      $error_message = "Titeln på din vara får inte vara tomt."
      return
    elsif info.nil? || info.strip.empty?
      $error_message = "Information om din vara får inte vara tomt."
      return
    elsif pris.nil? || pris.strip.empty?
      $error_message = "Priset på din vara får inte vara tomt."
      return
    elsif img.nil? || img.strip.empty?
      $error_message = "Du måste ha en bild"
      return
    end

    if senaste_annons_expired?
      $senaste_annons_time = Time.now
      db = connect_to_db('db/todo.db')
      db.execute("INSERT INTO annonser (content, genre, user_id, pris, info, img, genre2) VALUES (?,?,?,?,?,?,?)", content, genre_name, user_id, pris, info, img, genre_name2)
      annons_id = db.last_insert_row_id
      genre_id_result = db.execute("SELECT id FROM genre WHERE name = ?", genre_name).first
      genre_id_result2 = db.execute("SELECT id FROM genre WHERE name = ?", genre_name2).first
      db.execute("INSERT INTO genre_annonser (genre_id, genre_id2, annons_id) VALUES (?, ?, ?)", genre_id_result[0], genre_id_result2[0], annons_id)
    else
      $error_message = "För snabbt! Försök igen om en stund."
    end
  end

  # Method for retrieving user-specific advertisement details.
  # @param [Integer] user_id The ID of the current user.
  # @param [Integer] id The ID of the advertisement to be displayed.
  # @see connect_to_db
  # @see cuser_annons_id
  def user_id(user_id, id)
    db = connect_to_db('db/todo.db')
    user_annons_id = db.execute("SELECT user_id FROM annonser WHERE id = ?", id).first
    user_annons_id(user_annons_id, user_id)
    result = db.execute("SELECT * FROM annonser WHERE id = ?", id).first
    user_info = db.execute("SELECT username FROM users WHERE id = ?", result['user_id']).first
    username = user_info["username"] if user_info
    kommentarer = db.execute("SELECT kommentarer.*, users.username AS kommentar_username FROM kommentarer JOIN users ON kommentarer.user_id = users.id WHERE annons_id = ?", id)
    slim(:"annonser/show",locals:{result:result,username:username,kommentarer:kommentarer})
  end

  # Method for retrieving details of a specific advertisement.
  # @param [Integer] user_id The ID of the current user.
  # @param [Integer] id The ID of the advertisement to retrieve details for.
  # @see connect_to_db
  def annons_id(user_id, id)
    db = connect_to_db('db/todo.db')
    result = db.execute("SELECT * FROM annonser WHERE id = ?", id).first
    user_info = db.execute("SELECT username FROM users WHERE id = ?", result['user_id']).first
    username = user_info["username"] if user_info
    kommentarer = db.execute("SELECT kommentarer.*, users.username AS kommentar_username FROM kommentarer JOIN users ON kommentarer.user_id = users.id WHERE annons_id = ?", id)
    slim(:"annonser/show",locals:{result:result,username:username,kommentarer:kommentarer})
  end

  # Method for adding a new comment to an advertisement where it chekcs the time since last comment as well as handles and validates the input.
  # @param [String] comment The content of the new comment.
  # @param [Integer] user_id The ID of the user adding the comment.
  # @param [Integer] annons_id The ID of the advertisement to add the comment to.
  # @param [String] current_route The current route from which the comment is being added.
  # @see $error_message
  # @see kolla_tiden
  # @see updatera_tiden
  def comment_new(comment, user_id, annons_id, current_route)
    if comment.nil? || comment.strip.empty?
        $error_message = "Kommentaren får inte vara tom."
        redirect(current_route)
    end

    if kolla_tiden
        db = SQLite3::Database.new("db/todo.db")
        db.execute("INSERT INTO kommentarer (comment, user_id, annons_id) VALUES (?, ?, ?)", comment, user_id, annons_id)
        updatera_tiden
        redirect(current_route)
    else
        $error_message = "Du kan inte lägga till en kommentar så snabbt efter din senaste kommentar."
        redirect(current_route)
    end
end

  # Method for deleting a comment from an advertisement.
  # @param [Integer] kommentar_id The ID of the comment to be deleted.
  # @param [Integer] user_id The ID of the user who owns the comment.
  # @param [Integer] annons_id The ID of the advertisement the comment belongs to.
  # @param [String] current_route The current route from which the comment is being added.
  def comment_delete(kommentar_id, user_id, annons_id, current_route)
    if kommentar_id.nil?
      redirect(current_route)
    else
      db = SQLite3::Database.new("db/todo.db")
      annons_user_id = db.execute("SELECT user_id FROM annonser WHERE id = ?", annons_id).flatten.first
      user_comment(annons_user_id, user_id)
      db.execute("DELETE FROM kommentarer WHERE kommentar_id = ?", kommentar_id)
      redirect(current_route)
    end
  end

  # Method for displaying the edit page for an advertisement from a user's acoount page.
  # @param [Integer] user_id The ID of the current user.
  # @param [Integer] id The ID of the advertisement to edit.
  # @see connect_to_db
  def user_edit(user_id, id)
    db = connect_to_db('db/todo.db')
    user_annons_id = db.execute("SELECT user_id FROM annonser WHERE id = ?", id).first
    user_annons_id(user_annons_id, user_id)
    result = db.execute("SELECT * FROM annonser WHERE id = ?", id).first
    genres = db.execute("SELECT * FROM genre")
    slim(:"/annonser/edit",locals:{result:result,genres:genres})
  end

  # Method for updating an advertisement with the new information and validating it and then redirects to the user's account ('/konto').
  # @param [Integer] id The ID of the advertisement to update.
  # @param [String] content The new content/title of the advertisement.
  # @param [String] info The new additional information of the advertisement.
  # @param [Integer] pris The new price of the advertisement.
  # @param [String] genre_name The new genre of the advertisement.
  # @param [String] genre_name2 The second new genre of the advertisement.
  # @param [Integer] user_id The ID of the user updating the advertisement.
  # @see $error_message
  # @see user_annons
  def user_update(id, content, info, pris, genre_name, user_id, genre_name2)
    db = SQLite3::Database.new("db/todo.db")
    annons_user_id = db.execute("SELECT user_id FROM annonser WHERE id = ?", id).flatten.first
    genre_id = db.execute("SELECT id FROM genre WHERE name = ?", genre_name).flatten.first
    genre_id2 = db.execute("SELECT id FROM genre WHERE name = ?", genre_name2).flatten.first

    user_annons_id(annons_user_id, user_id)
    if content.nil? || content.strip.empty?
      $error_message = "Titeln på din vara får inte vara tomt."
      redirect('/konto')
    elsif info.nil? || info.strip.empty?
      $error_message = "Information om din vara får inte vara tomt."
      redirect('/konto')
    elsif pris.nil? || pris.zero?
      $error_message = "Priset på din vara får inte vara tomt."
      redirect('/konto')
    end
    if params[:img]
      img = params[:img][:tempfile].read
      db.execute("UPDATE annonser SET content=?, genre=?, pris=?, info=?, genre2=?, img=? WHERE id = ?", content, genre_name, pris, info, genre_name2, img, id)
    else
      db.execute("UPDATE annonser SET content=?, genre=?, pris=?, info=?, genre2=? WHERE id = ?", content, genre_name, pris, info, genre_name2, id)
      db.execute("UPDATE genre_annonser SET genre_id=?, genre_id2=? WHERE annons_id = ?", genre_id, genre_id2, id)
    end
    redirect('/konto')
  end

end
