$(document).ready(function(){
  $('.datepicker').pickadate({
    selectMonths: true, // Creates a dropdown to control month
    selectYears: 10 // Creates a dropdown of 15 years to control year
  });
  $('.ad_table').tablesorter();
  $('.close-flash').click(function(){
    $('.flash').fadeOut(1100);
  });

  $('.toggle-completed').click(function(){
    $('.completed').toggle();
  });

  $('#repeat').click(function(){
    $('#repeat-dates').toggle();
    $('.single-publication').toggle();
  });

  $('.toggle-note').leanModal();

  $(".button-collapse").sideNav();

});
