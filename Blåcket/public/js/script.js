//Den hämtar element, genre-select och annons-element. Lyssnar på händelse / vi väljer genre. Loppar igenom de som har det och ändrar block och none

// document.addEventListener('DOMContentLoaded', function() {
//   const genreSelect = document.getElementById('genre-select');
//   const annonser = document.querySelectorAll('.anons-element');

//   genreSelect.addEventListener('change', function() {
//     const selectedGenre = genreSelect.value;

//     annonser.forEach(function(annon) {
//       const genre = annon.dataset.genre;

//       if (selectedGenre === 'Alla' || genre === selectedGenre) {
//         annon.style.display = 'block';
//       } else {
//         annon.style.display = 'none';
//       }
//     });
//   });
// });