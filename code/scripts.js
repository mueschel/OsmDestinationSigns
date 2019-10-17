function getData(command,dId,callback,data="") {
  
  var xmlhttp = null;
  var cb = null;
  xmlhttp=new XMLHttpRequest();
  cb = callback;
  var destId = dId;
  var cmd = command;
  var dat = data;
  
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
  if(dat=="") {
    xmlhttp.open("GET",command,1);
    xmlhttp.send(null);
    }
  else {
    xmlhttp.open("POST",command,1);
    xmlhttp.send(dat);
    }
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

function showdata(d) {
  var data;
  try {
    data = JSON.parse(d);
    
    document.getElementById('container').innerHTML = "";
    if (data) {
      document.getElementById('container').innerHTML = data;
      }
//     if(data.html) {  
//       document.getElementById('container').innerHTML += data.html;
//       }
    } 
  catch (e) {
    document.getElementById('container').innerHTML = d;
    }
  if(cleanup) {cleanup();}
  }
  
  
function getsign(node) {
  var url = '../code/generate.pl?';
  var namedroutes = document.getElementsByName('namedroutes')[0].checked?'&namedroutes':'';
  var fromarrow = document.getElementsByName('fromarrow')[0].checked?'&fromarrow':'';
  
  url += 'nodeid='+node+namedroutes+fromarrow;
  getData(url,'',updatemap);
  document.getElementsByName("nodeid")[0].value = node;
  updatelink('node');
  document.getElementById('container').innerHTML = "<h3>Loading...</h3>";
  }

function getsvgsign(d) {  
  loaddata_i(d);
  }  
  
function loaddata_i(mydata) {
  var url = '../../destinations/code/generate.pl';
  
  mydata.direction = 0;
  mydata.country = "DE";
  mydatastr = JSON.stringify(mydata);
  getData(url,'',showdata,mydatastr);
  
  document.getElementsByName('wayid')[0].value = mydata.id;
  updatelink('way');
  document.getElementById('container').innerHTML = "<h3>Loading...</h3>";
  }  
  
  
function showObj(t,i) {
  window.open("https://osm.org/"+t+"/"+i);
}

function updatelink(t) {
  if(t) {currentType=t;}
  var node = document.getElementsByName("nodeid")[0].value;
  var way  = document.getElementsByName("wayid")[0].value;
  var namedroutes = document.getElementsByName('namedroutes')[0].checked?'&namedroutes=1':'namedroutes=0';
  var fromarrow = document.getElementsByName('fromarrow')[0].checked?'&fromarrow=1':'fromarrow=0';
  var include_sgn = document.getElementsByName('include_sgn')[0].checked?'&include_sgn=1':'&include_sgn=0';
  var include_way = document.getElementsByName('include_way')[0].checked?'&include_way=1':'&include_way=0';
  if(currentType == "way") {
    document.getElementById("permanode").href = '#way='+way+namedroutes+fromarrow+include_sgn+include_way;
    }
  else  {
    document.getElementById("permanode").href = '#node='+node+namedroutes+fromarrow+include_sgn+include_way;
    }
  }
