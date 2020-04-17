var map;
var bounds = new google.maps.LatLngBounds();
var position;
var infowindow = null;
var marker;
var geocoder = new google.maps.Geocoder();
function htmlDecode(input){
  var e = document.createElement('div');
  e.innerHTML = input;
  return e.childNodes[0].nodeValue;
}

var debug = false;

function initialize() { 
  div = document.getElementById("map_canvas");
  if (div == null) return null;
  map = new google.maps.Map(div,{
      zoom:  (markers.length <= 1) ? 15 : 10,
      panControl: false,
      zoomControl: true,
      mapTypeControl: true,
      scaleControl: true,
      streetViewControl: false,
      overviewMapControl: false,

      center: centre,
      mapTypeId: 'satellite'
      }); 
   addMarkers();
   if (markers.length > 0)map.fitBounds(bounds);

   infowindow =  new google.maps.InfoWindow( {
          content: "loading ... "
       });         
   if (markers.length == 1) {
        google.maps.event.addListenerOnce(map, 'zoom_changed', function() {
             map.setZoom(17); 
        });
       }
          
   if (draggable) {
      if ($('#latitude').val() == '')  {
             position = centre;
             var ezoom=14;
      } else {
             position = new google.maps.LatLng($('#latitude').val(),$('#longitude').val());
             var ezoom = 19;
      }
       if(debug)  alert(position + " " + ezoom);
       marker = new google.maps.Marker({
          position: position,
          draggable: true,
          title: $('#id').val(),
          map: map,
          icon: "http://maps.google.com/mapfiles/kml/pal4/icon49.png"
       });
      map.setCenter(position);
      map.setZoom(ezoom);
 
      google.maps.event.addListener(
         marker,
         'drag',
         function () {
             updatePosition(marker.getPosition(),false);
          }
       );
      google.maps.event.addListener(
         marker,
         'dragend',
         function () {
             updatePosition(marker.getPosition(),true);
          }
       );     
      }
      if (debug) alert(map.center);

}   

function addMarkers() {
   for (i in markers){
       var m = markers[i];
       var text = htmlDecode(m[3]);        
       position = new google.maps.LatLng(m[1],m[2]);
       bounds.extend(position);
       var icon = m[4];
        marker = new google.maps.Marker({
          position: position,
          title: m[0],
          map: map,
          icon: icon,
          html: text
       });
       google.maps.event.addListener(marker,'click', function() {
            infowindow.setContent(this.html);
            infowindow.open(map, this);
        });
   }
   map.setB
 }

function setMarker() {  
  position = new google.maps.LatLng($('#latitude').val(),$('#longitude').val());
  marker.setPosition(position); 
  map.setCenter(position);
}

function updatePosition(latlng,centreMap) {
  $('#latitude').val( Math.round(latlng.lat()*1000000) / 1000000 );
  $('#longitude').val( Math.round(latlng.lng()*1000000) / 1000000);
  if (centreMap) map.setCenter(latlng);
}

function setCentre() {
  var latlng = map.getCenter();
  marker.setPosition(latlng);
  $('#latitude').val( Math.round(latlng.lat()*1000000) / 1000000 );
  $('#longitude').val( Math.round(latlng.lng()*1000000) / 1000000);
}

function address_lookup() {
    address = $('#addresslookup').val();
    if (address !="") {
       geocoder.geocode(
       {'address':address} , 
       function(results,status) {
         if (status==google.maps.GeocoderStatus.OK) {
            var latlng = results[0].geometry.location;
            marker.setPosition(latlng);
            updatePosition(latlng,true);
            map.setZoom(16);

          } else 
            alert("Geocoding "+address +" was not successful for the following reason: " + status);
      }
     );
   }
}

$(document).ready(function() {   
    initialize ();
 
  });
