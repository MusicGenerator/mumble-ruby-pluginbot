function collapse_tree() {
  $('.node li:last-child').addClass('last-child');
  $('.node ul ul').hide();
  $('.node li:has(ul)').addClass('hassub').find('>span, >a').toggle(
    function() {
      $(this).parent().addClass('expand').find('>ul').slideDown('200');
    },
    function() {
      $(this).parent().removeClass('expand').find('>ul').slideUp('200');
    }
  );
}

function sendXhr (uri, id) {
  var xhr;
  if (window.XMLHttpRequest) {
    xhr = new XMLHttpRequest();
  } else if (window.ActiveXObject) {
    xhr = new ActiveXObject('MSXML2.XMLHTTP');
  } else {
    return false;
  }
  xhr.open("GET", uri, true);
  xhr.addEventListener('load',
    function(event) {
      if (xhr.status == 200) {
        var element = document.getElementById(id);
        if (element.innerHTML != xhr.responseText) {
          element.innerHTML = xhr.responseText;
          element.scrollTop = element.scrollHeight;
        }
      }
    }
  );
  xhr.send(null);
}

function GetLogFile () {
  x = document.getElementById('activelog')
  if ( x.style.display == "block" ) {
    sendXhr ('prozess.rb?command=logfile', 'activelog');
  }
  setTimeout(GetLogFile, 1000);
}
function toggle(id) {
  var x = document.getElementById(id)
  x.style.display = x.style.display == "none" ? "block" : "none";
}

function deluser(key) {
  alert(key);
}
function adduser(key) {
  var send = "process.rb?suadd="+key;
  alert(send)
  sendXhr(send);
}

function banuser(key) {
  var send = "process.rb?ubann="+key;
  alert(send);
  sendXhr(send);
}

function showPanel(id) {
  var i;
  x = document.getElementsByClassName("page");
  for ( i = 0; i < x.length; i++) {
    x[i].style.display = "none"
  }
  x = document.getElementById(id)
  x.style.display = "block"
}
function fill(text) {
  var i;
  x = document.getElementsByName('input')
  for (i = 0; i < x.length; i++) {
    x[i].style.display = "none";
  }
  document.getElementById(text).style.display = "block";
  x = document.getElementsByTagName('li');
  for (i = 0; i < x.length; i++) {
    x[i].style = "background-color: #ffffff;";
  }
  document.getElementById("listid"+text).style = "background-color: #e0e0ff;"
}
function hide(id) {
  document.getElementById(id).style.display = "none";
}

function command(command) {
  sendXhr('prozess.rb?command=stop', 'messages')
}

function post(form) {
  $.post("index.html"), $(form).serialize(), function(data) {
    alert(data);
  }
}


function start() {
  GetLogFile();
  sendXhr('prozess.rb?getserverusers=true', 'serveruser');
  sendXhr('prozess.rb?getsuperusers=true', 'configsuperuser');
  sendXhr('prozess.rb?getbannedusers=true', 'configbanneduser');
  sendXhr('prozess.rb?getedits=true', 'editfield');
  sendXhr('prozess.rb?showconfig=true', 'configuration');
  var i;
  var x = document.getElementsByName('input')
  for (i = 0; i < x.length; i++) {
    x[i].style.display = "none";
  }
}
