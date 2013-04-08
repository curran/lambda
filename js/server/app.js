// Just a static file server.
// Run with Node.js using 'node app.js'
//
// Needed for development of the code that
// gets the grammar text through AJAX.
//
// If file URLs are used and index.html is loaded,
// the browser complains with the following error:
// "Origin null is not allowed by Access-Control-Allow-Origin."
// Solution: use this server to serve the files.
var express = require('express');
var app = express();
var port = 8080;

app.use(express.static('../'));

app.listen(port);
console.log('Listening on port '+port);
