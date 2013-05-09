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

        it("should accept correct tags", function (done) {
            request(req, function(error, response, body) {
                should.not.exist(error);
                response.statusCode.should.equal(200);
                done();
            });
        });

        it("should store tags in the db", function(done) {
            request(req, function(err, res, body) {
                var getTag = {
                    url: "http://" + HOST + ":" + PORT + "/tag/newTag",
                    method: "GET"
                };

                request(getTag, function (error, response, tagBody) {
                    should.not.exist(error);
                    response.statusCode.should.equal(200);

                    var parsedBody = JSON.parse(tagBody);
                    parsedBody.name.should.equal("newTag");
                    parsedBody.queues.length.should.equal(2);

                    done();
                });
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
        var removeTag;

        beforeEach(function (done) {
            var createTag = {
                url: "http://" + HOST + ":" + PORT + "/tag",
                method: "POST",
                json: {}
            };
            removeTag = {
                url: "http://" + HOST + ":" + PORT + "/tag/tag1",
                method: "DELETE",
                json: {}
            };
            createTag.json.name = "tag1";
            createTag.json.queues = ["A1", "B1"]
            request(createTag, function (error, response, body) {
                done();
            });
        });

        it("should erase it from Redis", function (done) {
            request(removeTag, function (error, response, body) {
                var getTag = {
                    url: "http://" + HOST + ":" + PORT + "/tag/tag1",
                    method: "GET",
                    json: {}
                };

                request(getTag, function(error, response, tag) {
                    tag.queues.length.should.equal(0);
                    done();
                });
            });
        });
    });

    describe("When a message is posted to a tag", function () {
        var publish;

        beforeEach(function(done) {
            var createTag = {
                url: "http://" + HOST + ":" + PORT + "/tag",
                method: "POST",
                json: {}
            };

            publish = {
                url: "http://" + HOST + ":" + PORT + "/trans",
                method: "POST",
                json: {
                    "payload": "Published message",
                    "priority":"H",
                    "callback":"http://foo.bar",
                    "queue":[
                    ],
                    "tags": [
                        "tag2"
                    ]
                }
            };

            createTag.json.name = "tag1";
            createTag.json.queues = ["A1", "B1"]
            request(createTag, function (error, response, body) {
                createTag.json.name = "tag2";
                createTag.json.queues = ["A2", "B2"]
                request(createTag, function (error, response, body) {
                    done();
                });
            });
        });

        it ("should publish to all the inboxes associated to the tag", function (done) {
            request(publish, function(error, response, body) {
                response.statusCode.should.equal(200);

                var checkQueue = {
                    url: "http://" + HOST + ":" + PORT + "/queue/B2/pop",
                    method: "POST"
                }

                request(checkQueue, function (error, response, body) {
                    response.statusCode.should.equal(200);

                    var parsedBody = JSON.parse(body);
                    should.exist(parsedBody.data);
                    parsedBody.data.length.should.equal(1);
                    done();
                });
            });
        });
    });

    describe("When a queue is appended to a tag", function() {
        var updateTag;

        beforeEach(function (done) {
            var createTag = {
                url: "http://" + HOST + ":" + PORT + "/tag",
                method: "POST",
                json: {
                    name: "tag1",
                    queues: ["A1", "B1"]
                }
            };

            updateTag = {
                url: "http://" + HOST + ":" + PORT + "/tag",
                method: "POST",
                json: {
                    name: "tag1",
                    queues: ["C1", "D1", "E1"]
                }
            };

            request(createTag, function (error, response, body) {
                done();
            });
        });

        it("should update the tag", function(done) {
            request(updateTag, function (error, response, body) {
                var getTag = {
                    url: "http://" + HOST + ":" + PORT + "/tag/tag1",
                    method: "GET",
                    json: {}
                };

                request(getTag, function(error, response, tag) {
                    tag.queues.length.should.equal(5);
                    done();
                });
            });
        });
    });

    after(function(done) {
        utils.cleanBBDD(function() {
            agent.stop(done);
        } );
    });
});