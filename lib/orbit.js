var Yargs = require('yargs').argv;
var fs = require('fs');
var peg = require('./orbit.parser.js');

module.exports.parseOrbit = function(src) {
   return peg.parse(src);
}

function run(data) {
  if (data == null || data.length == 0) {
    console.log('Nothing to parse');
  } else {
    try {
      let prog = peg.parse(data + "\n");
      console.log(JSON.stringify(prog, null, 2));
    } catch (e) {
      console.log('ERROR: ' + e);
    }
  }
}

if (Yargs.expression !== undefined) {
  run(Yargs.expression);
} else if(Yargs.input !== undefined) {
  fs.readFile(Yargs.input, 'utf8', function(err, data) {
    if (err) {
      return console.log(err);
    }

    run(data);
  });
}
