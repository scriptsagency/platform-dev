(function($) {

//Get a CKEDITOR.dialog.contentDefinition object by its ID.
var getById = function(array, id, recurse) {
  for (var i = 0, item; (item = array[i]); i++) {
    if (item.id == id) return item;
      if (recurse && item[recurse]) {
        var retval = getById(item[recurse], id, recurse);
        if (retval) return retval;
    }
  }
  return null;
};

CKEDITOR.on( 'dialogDefinition', function( ev ) {
  // Take the dialog name and its definition from the event data.
  var dialogName = ev.data.name;
  var dialogDefinition = ev.data.definition;
  var dialog = CKEDITOR.dialog.getCurrent();

  if(dialogName == 'link') {
    var info =  dialogDefinition.getContents('info');
    // Add a html element to display message.
    info.add({
      id : 'check_url_msg',
      type : 'html',
      html : '<div id="url_check_msg"></div>',
    }, 'linkType');
    // Change the order of the html element in the dialog box.
    elt = info.elements[0];
    info.elements[2].children.push(elt);
    info.elements.shift();
    
    // Create and add a custom button to check the URL.
    dialogDefinition.buttons.unshift({
      type : 'button',
      id : 'check_url_btn',
      label : 'Check URL',
      title : 'title',
      style   : 'color:green',
      onClick : function() {
        var dialog = CKEDITOR.dialog.getCurrent();
        elem_url = dialog.getContentElement('info','url');
        elem_protocol = dialog.getContentElement('info','protocol');
        urlencoded = encodeURIComponent(elem_protocol.getValue()+elem_url.getValue());
        check = urlExists(Drupal.settings.basePath+'check_url?url='+urlencoded);
      }
    });

    // Override the onShow event to display custom elements.
    dialogDefinition.onShow = CKEDITOR.tools.override(dialogDefinition.onShow, function(original) {
      return function() {
        original.call(this);

        var dialog = CKEDITOR.dialog.getCurrent();
        elem_check_url_btn = dialog.getButton('check_url_btn');
        elem_ok = dialog.getButton('ok');
        elem_linkType = dialog.getContentElement('info','linkType');

        if(elem_linkType.getValue() == 'url') {
          elem_check_url_btn.getElement().show();
          elem_ok.getElement().hide();
        }
        else {
          elem_check_url_btn.getElement().hide();
          elem_ok.getElement().show();
        }
        
      };
    });


    var elem_linkType = getById(info.elements, 'linkType');
    // Override the onChange event of the linkType element to manage the buttons display
    elem_linkType.onChange = CKEDITOR.tools.override(elem_linkType.onChange, function(original) {
      return function() {
        original.call(this);

        elem_check_url_btn = this.getDialog().getButton('check_url_btn');
        elem_ok = this.getDialog().getButton('ok');
        if(this.getValue() == 'url') {
          elem_check_url_btn.getElement().show();
          elem_ok.getElement().hide();
        }
        else {
          elem_check_url_btn.getElement().hide();
          elem_ok.getElement().show();
        }
      };
    });


  }


  function urlExists(url){
    $('#url_check_msg').html('Checking url... <img src="'+Drupal.settings.basePath+'misc/throbber-active.gif"/>');
    $.getJSON(url)
      .done(function( data ) {
        console.log(data);
        if(data == true) {
          $('#url_check_msg').html('');
          $('#url_check_msg').css({ 'color': 'green', 'font-weight': 'bold' });
          // submit the dialog box form
          $('.cke_dialog_ui_button_ok span').click();
        }
        else {
          $('#url_check_msg').html('Url not exists');
          $('#url_check_msg').css({ 'color': 'red', 'font-weight': 'bold' });
          $('.cke_dialog_ui_button_ok').hide();
        }
      })
      .fail(function( jqxhr, textStatus, rror ) {
        var err = textStatus + ", " + error;
        console.log( "Request Failed: " + err );
        $('#url_check_msg').html('Network error');
        $('#url_check_msg').css({ 'color': 'red', 'font-weight': 'bold' });
     });
  }

});

})(jQuery);
