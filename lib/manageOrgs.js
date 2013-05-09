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

var config = require('./config.js');

/**
 * Reads the Org Id from the URL or from the headers, adding it to the request. If there is a queue name
 * present in the URL, it is also prefixed with the org name to isolate inboxes between orgs.
 *
 * @param req
 * @param res
 * @param next
 */
function appendOrg(req, res, next) {
    var orgName;

    if (config.oauthIdToken) {
        orgName = req.headers[config.oauthIdToken];
    } else {
        orgName = req.params.id_org;
    }

    if (req.params && req.params.id) {
        req.params.id = orgName + "|" + req.params.id;
    }

    req.org = orgName;

    next();
}

/**
 * Rewrite trans bodies to add the org name to the inbox in the input bodies and extract it on the output.
 *
 * @param req
 * @param res
 * @param next
 */
function rewriteTrans(req, res, next) {
    var orgPrefix = req.org + "|";

    if (req.body.queue) {
        for (q in req.body.queue) {
            req.body.queue[q].id = orgPrefix + req.body.queue[q].id;
        }
    }

    var end = res.end;
    res.end = function(chunk, encoding){
        res.end = end;
        var cleanChunk = chunk;

        if (cleanChunk) {
            cleanChunk = cleanChunk.replace(new RegExp(req.org + "\\|", "g"), "");
        }
        res.end(cleanChunk, encoding);
    };

    next();
}

exports.appendOrg = appendOrg;
exports.rewriteTrans = rewriteTrans;