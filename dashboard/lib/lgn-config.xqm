module namespace config ="http://kitwallace.co.uk/lib/config";
declare variable $config:base := "/db/apps/logger/";
declare variable $config:root := "https://kitwallace.co.uk/logger/dashboard.xq";
declare variable $config:users := doc(concat($config:base,"ref/users.xml"))/users;
declare variable $config:secret := "treecare";
declare variable $config:site-name := "Sensor Logger";
