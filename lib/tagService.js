/**
 *Copyright 2012 Telefonica Investigación y Desarrollo, S.A.U
 *
 *This file is part of PopBox.
 *
 *PopBox is free software: you can redistribute it and/or modify it under the terms of the GNU Affero General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
 *PopBox is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU Affero General Public License for more details.
 *
 *You should have received a copy of the GNU Affero General Public License along with PopBox
 *. If not, seehttp://www.gnu.org/licenses/.
 *
 *For those usages not covered by the GNU Affero General Public License please contact with::dtc_support@tid.es

 * Created with JetBrains WebStorm.
 * User: mru
 * Date: 16/01/13
 * Time: 13:42
 */
"use strict";

var uuid = require('node-uuid'),
    async = require('async'),
    dbCluster = require('./dbCluster.js');

function addElementHandler(db, name, value) {
    return function (redisCallback) {
        db.sadd(name, value, redisCallback);
    };
}
function createTagInRedis(tagBody, callback) {
    var db = dbCluster.getTransactionDb(tagBody.name),
        redisActions = [];

    for (var i=0; i <tagBody.queues.length; i++) {
        redisActions.push(addElementHandler(db, tagBody.name, tagBody.queues[i]));
    }

    async.parallel(redisActions, callback);
}

function createTag(req, res) {
    var errors = [];

    if (!req.body.name) {
        errors.push("missing name");
    }

    if (!req.body.queues || req.body.queues.length == 0) {
        errors.push("missing queues");
    }

    if (errors.length != 0) {
        res.send({errors: errors}, 400);
    } else {
        createTagInRedis(req.body, function (error) {
            if (error) {
                res.send({errors: error}, 500);
            } else {
                res.send({ok: "tag stored"}, 200);
            }
        });
    }
}

exports.createTag = createTag;