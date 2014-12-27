// Copyright 2014 Thomas Thomassen

var KEY_TAB = 9;


$(document).ready(function() {

  $("#fix-all").on("click", function() {
    callback("fix_all");
    return false;
  });

  $(document).on("click", ".error-group .expand_info", function() {
    var $this = $(this);
    $this.siblings(".description").toggle();
    return false;
  });

  $(document).on("click", ".error-group > .fix", function() {
    var $this = $(this);
    var $error_group = $this.parent();
    var type = $error_group.data("type");
    var data = { "type" : type }
    callback("fix_group", data);
    return false;
  });

  $(document).on("click", ".error-group", function() {
    $(".error-group").removeClass("selected");
    var $error_group = $(this);
    $error_group.toggleClass("selected");

    var data = $error_group.data("type");
    callback("select_group", [data]);

    return false;
  });

  $(document).on("click", "#content", function() {
    $(".error-group").removeClass("selected");
    callback("select_group", [null]);
    return false;
  });

  /*
  // Key up and down trigger too mast for async OSX.
  $(document).on("keydown", function(event) {
    return false;
    callback("keydown", { key : event.which });
    if (event.which == KEY_TAB) {
      event.preventDefault();
      return true;
    }
    return false;
  });
  */
  $(document).on("keyup", function(event) {
    callback("keyup", { key : event.which });
    if (event.which == KEY_TAB) {
      event.preventDefault();
      return true;
    }
    return false;
  });

});


function update_ui() {
  var $error_groups = $(".error-group");

  // Display friendly message is there are no errors.
  if ($error_groups.length == 0) {
    var html = "\
      <div id='no-errors'>\
        No Errors<br>\
        Everything is shiny\
        <div id='smiley'>:)</div>\
      </div>";
    $("#content").html(html);
  }

  // Enable/Disabled the "Fix All" button.
  $("#fix-all").prop("disabled", $error_groups.length == 0);
}


function list_errors(errors) {
  // Clear old content.
  $("#content").text("");

  for (error_type in errors) {
    var error_group = errors[error_type];
    add_error_type(error_group);
  }

  update_ui();
}


function update_errors(errors) {
  for (error_type in errors) {
    var error_group = errors[error_type];
    if (error_group.errors.length > 0) {
      update_error_type(error_group);
    } else {
      remove_error_type(error_group);
    }
  }
  update_ui();
}


function add_error_type(error_group) {
  var fix_button_label = (error_group.fixable) ? "Fix" : "Info"
  html = '\
  <div class="error-group">\
    <div class="title">' + error_group.name + '</div>\
    <a class="expand_info" title="Click to expand help">\
      <img src="../images/Help-20.png" alt="?">\
    </a>\
    <div class="count">' + error_group.errors.length + '</div>\
    <div class="description">' + error_group.description + '</div>\
    <button class="fix">' + fix_button_label + '</button>\
  </div>';
  var $group = $(html);
  $group.addClass(error_group.type);
  $group.data("type", error_group.type);
  $("#content").append($group);
}


function remove_error_type(error_group) {
  var klass = "." + error_group.type;
  var $group = $(klass);
  $group.detach();
}


function update_error_type(error_group) {
  var klass = "." + error_group.type;
  var $group = $(klass);
  if ($group.length > 0) {
    add_error_type(error_group)
  } else {
    $group.children(".title").text(error_group.name);
    $group.children(".count").text(error_group.errors.length);
    $group.children(".description").text(error_group.description);
  }
}
