"use strict";

var should = require('should'),
    async = require('async'),
    utils = require('./../utils'),
    agent = require('../../.'),
    config = require('../config.js'),
    request = require("request");

var HOST = config.hostname;
var PORT = config.port;

describe.only('Tags', function() {

    beforeEach(function(done) {
        utils.cleanBBDD(done);
    });

    before(function(done){
        agent.start(done);
    });

    describe("When a new tag is created", function () {

        var req;

        beforeEach(function() {
            req = {
                url: "http://" + HOST + ":" + PORT + "/tag",
                method: "POST",
                json: {
                    name: "newTag",
                    queues: [
                        "queueName1",
                        "queueName2"
                    ]
                }
            };
        });

        it("should store it in Redis", function (done) {
            request(req, function(error, response, body) {
                response.statusCode.should.equal(200);
                done();
            });
        });

        it("should reject requests without name", function (done) {
            delete req.json.name;

            request(req, function(error, response, body) {
                response.statusCode.should.equal(400);
                done();
            });
        });

        it("should reject requests without queues", function (done) {
            delete req.json.queues;

            request(req, function(error, response, body) {
                response.statusCode.should.equal(400);
                done();
            });
        });

        it("should reject requests with an ampty queue list", function (done) {
            req.json.queues = [];

            request(req, function(error, response, body) {
                response.statusCode.should.equal(400);
                done();
            });
        });
    });

    describe("When a tag is removed", function () {
        it("should erase it from Redis");
    });

    describe("When a message is posted to a tag", function () {
        it ("should publish to all the inboxes associated to the tag");
    });

    after(function(done) {
        utils.cleanBBDD(function() {
            agent.stop(done);
        } );
    });
});