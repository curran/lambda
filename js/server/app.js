// Just a static file server.
// Run with Node.js using 'node server.js'
//
// Needed for development of the code that
// gets the grammar text through AJAX.
// If using the file system it complains with
// "Origin null is not allowed by Access-Control-Allow-Origin."
var express = require('express');
var app = express();
var port = 8080;

app.use(express.static('../'));
//app.use(express.directory(__dirname));

app.listen(port);
console.log('Listening on port '+port);
