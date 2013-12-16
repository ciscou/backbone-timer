scrambler_mega = function() {
  /* Program by Clément Gallet, based on earlier work by Jaap Scherphuis. Idea by Stefan Pochmann. */
  /* Hacked by Roger Lew for Android Cube Timer,  http://code.google.com/p/android-cubetimer/ */
  var linelen=10;
  var linenbr=7;
  var numcub=1;

  var seq=new Array();	// move sequences

  function parse() {
    var urlquery=location.href.split("?")
    if(urlquery.length>1){
      var urlterms=urlquery[1].split("&")
      for( var i=0; i<urlterms.length; i++){
        var urllr=urlterms[i].split("=");
        if(urllr[0]=="ll") {
          if(urllr[1]-0 >= 1 ) linelen=urllr[1]-0;
        } else if(urllr[0]=="ln"){
          if(urllr[1]-0 >= 1 ) linenbr=urllr[1]-0;
        } else if(urllr[0]=="num"){
          if(urllr[1]-0 >= 1 ) numcub=urllr[1]-0;
        }
      }
    }
  }

  function scramble(){
    var i,n;
    for( n=0; n<numcub; n++){
      seq[n]=new Array();
      for(i=0; i<linenbr*linelen; i++){
        seq[n][i]=Math.floor(Math.random()*2);
          }
    }
  }

  function scramblestring(n){
    var s="",i,j;
    for(j=0; j<linenbr; j++){
      for(i=0; i<linelen; i++){
        if (i%2)
        {
          if (seq[n][j*linelen + i]) s+="D++ ";
          else s+="D-- ";
        }
        else
        {
          if (seq[n][j*linelen + i]) s+="R++ ";
          else s+="R-- ";
        }
      }
      if (seq[n][(j+1)*linelen - 1]) s+="U\n";
      else s+="U'\n";
    }
    return s;
  }

  parse();
  scramble();
  return scramblestring(0);
}
