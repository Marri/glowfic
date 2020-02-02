$(document).ready(function() {
  // Use hide/show for anonymous users rather than removing content
  // server-side improves SEO as search bots can still scrape content.
  if ($("#tos").length > 0) {
    $("#content").hide();
    $("#tos").show();
  }
  $("#tos_form").submit(function() {
    /* save fragment (e.g. #reply-1234) for redirect */
    if (location.hash) {
      localStorage.setItem("tos.old_path", location.pathname);
      localStorage.setItem("tos.old_fragment", location.hash);
    }
  });
});
