$(document).ready(function(){
  $('.datepicker').pickadate({
    selectMonths: true, // Creates a dropdown to control month
    selectYears: 10 // Creates a dropdown of 15 years to control year
  });
  $('.ad_table').tablesorter();

  $('.close-flash').click(function(){
    $('.flash').fadeOut(1100);
  });

  $('.hide-completed').click(function(){
    $('.placed').hide();
  });
  $('.show-completed').click(function(){
    $('.placed').show();
  });

  $('#repeat').click(function(){
    $('#repeat-dates').toggle();
    $('.single-publication').toggle();
  });

  $('#deletecheck').click(function(){
    $('#delete').toggle();
  });

  $('.toggle-note').leanModal();

  $(".button-collapse").sideNav();

  $(".dropdown-button").dropdown({ hover: true, belowOrigin: true, constrain_width: false });

  $(".selectize").selectize({
    create: false
  });

  $('select').material_select();

  $('.delete-ad').click(function(){
    return confirm('Are you sure you want to delete this booking?');
  });
  $('#runonBody').keyup(function(){
    var word_count = $( this ).val().split(" ").length;
    $('#words').val(word_count);
  }).keyup;

  $('.tooltipped').tooltip({delay: 50});


});
