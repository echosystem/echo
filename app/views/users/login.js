/* Write render output into JS variable and put it into the container. */
var content = "<%= escape_javascript(render(:partial => 'new')) %>";
$j('#dialogContent').html(content);

/* Create a jqueryUI modal dialog with a send button. */
$j('#dialogContent').dialog({
  title:    "Feedback",
  bgiframe: true,
  modal:    true,
  buttons:  {
    "<%= I18n.t('application.general.send') %>":  function() { $j('#new_feedback_form').submit(); },
    "<%= I18n.t('application.general.cancel') %>": function() { $j(this).dialog('close'); }
  },
  close:    function(event, ui) { $j(this).dialog('destroy'); },
  width:    650,
  resizable: false
});

<% if current_user %>
  $j('#feedback_message').focus();
<% end %>