var gulp =       require('gulp');
var gutil =      require('gulp-util');
var uglify =     require('gulp-uglify');
var jshint =     require('gulp-jshint');
var webpack =    require('gulp-webpack');
var rename =     require('gulp-rename');
var coffee =     require('gulp-coffee');
var concat =     require('gulp-concat');
var header =     require('gulp-header');
var git =        require('gulp-git');
var runSeq =     require('run-sequence');
var fs =         require('fs');
var del =        require('del');
var exec =       require('child_process').exec;

gulp.task('clone-prerender', function(cb) {
  if (!fs.existsSync('./prerender')) {
    var arg = 'clone https://github.com/prerender/prerender.git prerender';
    // console.log(arg)
    return git.exec({args:arg }, function (err, stdout) {
      cb();
    })
  }
  else {
    var arg = 'git fetch && git merge --ff-only origin/master';
    exec(arg, { cwd: process.cwd() + '/prerender'},
        function (error, stdout, stderr) {
          cb();
      });
  }
});

// clean
gulp.task('clean', function(cb) {
  del(['dist', './prerender/lib/plugins/public', './prerender/lib/plugins/gsn*.js', './prerender/gsn*.js'], cb);
});

// compile and copy plugin
gulp.task('coffee', function() {
  gulp.src(['./src/*.coffee'])
    .pipe(coffee({bare: true}).on('error', gutil.log))
    .pipe(gulp.dest('prerender'));

  return gulp.src(['./src/plugins/*.coffee'])
    .pipe(coffee({bare: true}).on('error', gutil.log))
    .pipe(gulp.dest('prerender/lib/plugins'))
});

// overwrite server
// run node



// run tasks in sequential order
gulp.task('default', function(cb) {
  runSeq('clean', 'clone-prerender','coffee', cb);
});
