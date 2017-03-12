function getData(command,dId,callback) {
  
  var xmlhttp = null;
  var cb = null;
  xmlhttp=new XMLHttpRequest();
  cb = callback;
  var destId = dId;
  var cmd = command;
  
  xmlhttp.onreadystatechange = function() {
    if(xmlhttp.readyState == 4) {
      if(destId && document.getElementById(destId)){
        document.getElementById(destId).innerHTML  = xmlhttp.responseText;  
        }
      if(cb) {
        cb(xmlhttp.responseText);
        }
      }
    }

  xmlhttp.open("GET",command,1);
  xmlhttp.send(null);
  }  

  
function updatemap(d) {
  var data;
  try {
    data = JSON.parse(d);
    document.getElementById('container').innerHTML = data.error + data.html;
    if(map){
      map.panTo([data.lat, data.lon]);
     }
    } 
  catch (e) {
    document.getElementById('container').innerHTML = d;
    }
  
}
  
  
function getsign(node) {
  var url = '../code/generate.pl?';
  var namedroutes = document.getElementsByName('namedroutes')[0].checked?'&namedroutes':'';
  var fromarrow = document.getElementsByName('fromarrow')[0].checked?'&fromarrow':'';
  
  url += 'nodeid='+node+namedroutes+fromarrow;
  getData(url,'',updatemap);
  }

function showObj(t,i) {
  window.open("https://osm.org/"+t+"/"+i);
}
