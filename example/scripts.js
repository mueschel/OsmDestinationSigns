function getData(command,dId,callback) {
  
  var xmlhttp = null;
  var cb = null;
  xmlhttp=new XMLHttpRequest();
  cb = callback;
  var destId = dId;
  var cmd = command;
  
  xmlhttp.onreadystatechange = function() {
    if(xmlhttp.readyState == 4) {
      if(document.getElementById(destId)){
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
      map.removeLayer(marker);
      marker = L.marker([data.lat, data.lon]).addTo(map);
      var group = new L.featureGroup([marker]);
      map.fitBounds(group.getBounds());
      }
    } 
  catch (e) {
    document.getElementById('container').innerHTML = d;
    }
  
}
  
  
function getsign(t) {
  var url = 'generate.pl?';
  var node = document.getElementsByName('nodeid')[t].value;
  var namedroutes = document.getElementsByName('namedroutes')[0].checked;
  var fromarrow = document.getElementsByName('fromarrow')[0].checked;
  
  url += 'nodeid='+node;
  url += '&namedroutes='+namedroutes
  url += '&fromarrow='+fromarrow
  getData(url,'',updatemap);
  }

function showObj(t,i) {
  window.open("https://osm.org/"+t+"/"+i);
}
