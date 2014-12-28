// Copyright 2014 Thomas Thomassen


var KEYCODE_ENTER = 13


// A hash with strings used for localization.
var l10n_strings = {};


window.onerror = function(message, location, linenumber, error) {
  alert(message + "\nLine: " + linenumber + "\nlocation: " + location + "\nerror: " + error);
  return false;
};


// Utility method to call back to Ruby, taking an optional JSON object as
// payload.
function callback(name, data) {
  // Defer with a timer in order to allow the UI to update.
  setTimeout(function() {
    $bridge = $("#SU_BRIDGE");
    $bridge.text("");
    if (data !== undefined) {
      var json = JSON.stringify(data);
      $bridge.text(json);
    }
    window.location = "skp:callback@" + name;
  }, 0);
}


$(document).ready(function() {

  create_bridge();
  disable_context_menu();
  disable_select();
  hook_up_close_button();
  hook_up_default_button();

  callback("html_ready");

});


// Creates a hidden textarea element used to pass data from JavaScript to
// Ruby. Ruby calls UI::WebDialog.get_element_value to fetch the content and
// parse it as JSON.
// This avoids many issues in regard to transferring data:
// * Data can be any size.
// * Avoid string encoding issues.
// * Avoid evaluation bug in SketchUp when the string has a single quote.
function create_bridge() {
  var $bridge = $("<textarea id='SU_BRIDGE'></textarea>");
  $bridge.hide();
  $("body").append($bridge);
}


function hook_up_default_button() {
  var $default_button = $("button[type=submit]");
  if ($default_button.length == 1) {

    $(document).keypress(function (event) {
      if (event.which == KEYCODE_ENTER) {
        $default_button.trigger('click');
        event.preventDefault();
        event.stopPropagation();
        return false;
      }
    });

  }
}


function hook_up_close_button() {
  $("#close").on("click", function() {
    callback("close_window");
  });
}


/* Disables text selection on elements other than input type elements where
 * it makes sense to allow selections. This mimics native windows.
 */
function disable_select() {
  $(document).on('mousedown selectstart', function(e) {
    return $(e.target).is('input, textarea, select, option, .selectable');
  });
}


/* Disables the context menu with the exception for textboxes in order to
 * mimic native windows.
 */
function disable_context_menu() {
  $(document).on('contextmenu', function(e) {
    return $(e.target).is('input[type=text], input[type=email], input[type=password], textarea, .selectable');
  });
}


// Gotto love JavsScript...
// http://stackoverflow.com/a/9436948/486990
function is_a_string(object) {
  return object instanceof String || typeof object == 'string';
}


// Returns a localized string if such exist.
function l10n(string) {
  var result = l10n_strings[string];
  if (result === undefined) {
    return string;
  } else {
    return result;
  }
}


// Call this method from WebDialog.
// This collects all the strings in the HTML that needs to be localized.
function localize(strings) {
  l10n_strings = strings;
  $(".localize").each(function() {
    var $this = $(this);
    var type = $this.prop('tagName').toLowerCase();

    switch(type) {

      case "input":
        var input = $this.attr("placeholder");
        var output = l10n(input);
        $this.attr("placeholder", output);
        break;

      default:
        var input = $this.text();
        var output = l10n(input);
        $this.text(output);
    }

  });
}


// http://stackoverflow.com/a/2838358/486990
function select_element_text(el, win) {
  win = win || window;
  var doc = win.document, sel, range;
  if (win.getSelection && doc.createRange) {
    sel = win.getSelection();
    range = doc.createRange();
    range.selectNodeContents(el);
    sel.removeAllRanges();
    sel.addRange(range);
  } else if (doc.body.createTextRange) {
    range = doc.body.createTextRange();
    range.moveToElementText(el);
    range.select();
  }
}
