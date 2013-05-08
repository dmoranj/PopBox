/*
 Copyright 2012 Telefonica Investigación y Desarrollo, S.A.U

 This file is part of PopBox.

 PopBox is free software: you can redistribute it and/or modify it under the
 terms of the GNU Affero General Public License as published by the Free
 Software Foundation, either version 3 of the License, or (at your option) any
 later version.
 PopBox is distributed in the hope that it will be useful, but WITHOUT ANY
 WARRANTY; without even the implied warranty of MERCHANTABILITY or
 FITNESS FOR A PARTICULAR PURPOSE. See the GNU Affero General Public
 License for more details.

 You should have received a copy of the GNU Affero General Public License
 along with PopBox. If not, seehttp://www.gnu.org/licenses/.

 For those usages not covered by the GNU Affero General Public License
 please contact with::dtc_support@tid.es
 */

var mongodb = require('mongodb');

var config = require('./config').evLsnr;

var path = require('path');
var log = require('PDITCLogger');
var logger = log.newLogger();
logger.prefix = path.basename(module.filename, '.js');


function init(emitter) {
  'use strict';
  return function(callback) {
    var db = new mongodb.Db(config.mongoDB,
        new mongodb.Server(config.mongoHost,
            config.mongoPort, {auto_reconnect: true}));
    db.open(function(errOpen, db) {
      if (! errOpen) {
        db.collection(config.collection, function(err, collection) {
          if (err) {
            if (callback) {
              callback(err);
            }
          } else {
            logger.info('mongo is susbcribed');
            emitter.on('NEWSTATE', function onNewState(data) {
              try {
                logger.debug('onNewState(data)', [data]);
                collection.insert(data, function(err) {
                  if (err) {
                    logger.warning('onNewState', err);
                  }
                });
              } catch (e) {
                logger.warning(e);
              }
            });
            emitter.on('ACTION', function onAction(data) {
              try {
                logger.debug('onAction(data)', [data]);
                collection.insert(data, function(err) {
                  if (err) {
                    logger.warning('onAction', err);
                  }
                });
              } catch (e) {
                logger.warning(e);
              }
            });
            if (callback) {
              callback(null);
            }
          }
        });
      }
      else {
        callback(errOpen);
      }
    });
  };
}

//Public area
/**
 *
 * @param {EventEmitter} emitter from event.js.
 * @return {function(function)} asyncInit funtion ready for async.
 */
exports.init = init;
