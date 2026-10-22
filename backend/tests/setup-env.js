'use strict';

// Tests always use the isolated test database and test secrets.
require('dotenv').config({ path: require('node:path').join(__dirname, '..', '.env.test'), quiet: true });
