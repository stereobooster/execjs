(function(program, execJS) { execJS(program) })(function() {
  return eval(#{escaped_source});
}, function(program) {
  var output;
  try {
    result = program();
    if (typeof result == 'undefined' && result !== null) {
      print('["ok"]');
    } else {
      try {
        print(JSON.stringify(['ok', result, null]));
      } catch (err) {
        print(JSON.stringify(['err', 'Cant\'t stringify result', null]));
      }
    }
  } catch (err) {
    print(JSON.stringify(['err', '' + err, null]));
  }
});
