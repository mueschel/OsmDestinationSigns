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
    
    document.getElementById('container').innerHTML = "";
    if (data.error) {
      document.getElementById('container').innerHTML = data.error;
      }
    if(data.html) {  
      document.getElementById('container').innerHTML += data.html;
      }
    
    //move map if out of bounds
    if(map && data.lat && data.lon && !map.getBounds().contains([data.lat, data.lon])){
      map.panTo([data.lat, data.lon]);
     }
    } 
  catch (e) {
    document.getElementById('container').innerHTML = "<h3>Error / Debugging</h3>"+ d;
    }
  
}
  
  
function getsign(node) {
  var url = '../code/generate.pl?';
  var namedroutes = document.getElementsByName('namedroutes')[0].checked?'&namedroutes':'';
  var fromarrow = document.getElementsByName('fromarrow')[0].checked?'&fromarrow':'';
  
  url += 'nodeid='+node+namedroutes+fromarrow;
  getData(url,'',updatemap);
  document.getElementById("permanode").href = '#node='+node;
  document.getElementsByName("nodeid")[0].value = node;
  document.getElementById('container').innerHTML = "<h3>Loading...</h3>";
  }

function showObj(t,i) {
  window.open("https://osm.org/"+t+"/"+i);
}
