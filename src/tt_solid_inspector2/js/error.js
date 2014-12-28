// Copyright 2014 Thomas Thomassen


function error_report(report) {
  $("#report").text("```text\n" + report.trim() + "\n```");
}


$(document).ready(function() {

  $("#report").on("click", function() {
    var element = $("#report").get(0);
    select_element_text(element);
  });

  $("#send-report").on("click", function() {
    var text_report = $("#report").text();
    try {
      window.clipboardData.setData("Text", text_report);
    } catch(error) {
      alert("Could not copy report to clipboard. Please manually copy it.");
    }
    callback("report");
  });

});
