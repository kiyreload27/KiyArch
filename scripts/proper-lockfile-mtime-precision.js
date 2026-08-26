'use strict';

// proper-lockfile 4.1.2 stores its cache on the fs object. Pi is bundled with
// Bun, where that fs object may be a Proxy; defining a non-configurable
// property on it then violates Proxy invariants on the next read.
const precisionCache = new WeakMap();

function probe(file, fs, callback) {
    const cachedPrecision = precisionCache.get(fs);

    if (cachedPrecision) {
        return fs.stat(file, (err, stat) => {
            if (err) {
                return callback(err);
            }

            callback(null, stat.mtime, cachedPrecision);
        });
    }

    const mtime = new Date((Math.ceil(Date.now() / 1000) * 1000) + 5);

    fs.utimes(file, mtime, mtime, (err) => {
        if (err) {
            return callback(err);
        }

        fs.stat(file, (err, stat) => {
            if (err) {
                return callback(err);
            }

            const precision = stat.mtime.getTime() % 1000 === 0 ? 's' : 'ms';
            precisionCache.set(fs, precision);
            callback(null, stat.mtime, precision);
        });
    });
}

function getMtime(precision) {
    let now = Date.now();

    if (precision === 's') {
        now = Math.ceil(now / 1000) * 1000;
    }

    return new Date(now);
}

module.exports.probe = probe;
module.exports.getMtime = getMtime;
