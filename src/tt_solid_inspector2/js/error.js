// Copyright 2014 Thomas Thomassen


function error_report(report) {
  $("#report").text(report);
}


$(document).ready(function() {

  $("#send-report").on("click", function() {
    var text_report = "```text\n" + $("#report").text() + "\n```";
    try {
      window.clipboardData.setData("Text", text_report);
    } catch(error) {
      alert("Could not copy report to clipboard. Please manually copy it.");
    }
    callback("report");
  });

});
