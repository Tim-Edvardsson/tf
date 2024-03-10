document.addEventListener('DOMContentLoaded', function() {
  const genreSelect = document.getElementById('genre-select');
  const annonser = document.querySelectorAll('.anons-element');

  genreSelect.addEventListener('change', function() {
    const selectedGenre = genreSelect.value;

    annonser.forEach(function(annon) {
      const genre = annon.dataset.genre;

      if (selectedGenre === 'Alla' || genre === selectedGenre) {
        annon.style.display = 'block';
      } else {
        annon.style.display = 'none';
      }
    });
  });
});