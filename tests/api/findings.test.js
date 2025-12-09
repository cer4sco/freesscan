const chai = require('chai');
const chaiHttp = require('chai-http');
const sinon = require('sinon');
const { expect } = chai;

chai.use(chaiHttp);

describe('Findings API', () => {
    let app;
    let poolStub;

    beforeEach(() => {
        poolStub = {
            query: sinon.stub()
        };

        // Clear server cache to get fresh instance
        delete require.cache[require.resolve('../../api/server.js')];
        app = require('../../api/server.js');
        
        // Directly replace the pool with our stub
        app.locals.pool = poolStub;
    });

    afterEach(() => {
        sinon.restore();
    });

    describe('GET /api/findings', () => {
        it('should return array of findings', (done) => {
            poolStub.query.resolves({
                rows: [
                    {
                        id: 1,
                        finding_type: 'aws_access_key_id',
                        severity_name: 'CRITICAL',
                        file_path: '.env',
                        line_number: 1
                    }
                ]
            });

            chai.request(app)
                .get('/api/findings')
                .end((err, res) => {
                    expect(err).to.be.null;
                    expect(res).to.have.status(200);
                    expect(res.body).to.be.an('array');
                    expect(res.body).to.have.lengthOf(1);
                    expect(res.body[0]).to.have.property('finding_type');
                    done();
                });
        });

        it('should filter by severity', (done) => {
            poolStub.query.resolves({
                rows: [
                    { id: 1, severity_name: 'CRITICAL' }
                ]
            });

            chai.request(app)
                .get('/api/findings?severity=CRITICAL')
                .end((err, res) => {
                    expect(res).to.have.status(200);
                    expect(res.body).to.be.an('array');
                    done();
                });
        });

        it('should filter by scan_id', (done) => {
            poolStub.query.resolves({ rows: [] });

            chai.request(app)
                .get('/api/findings?scan_id=1')
                .end((err, res) => {
                    expect(res).to.have.status(200);
                    expect(res.body).to.be.an('array');
                    done();
                });
        });

        it('should filter by is_false_positive', (done) => {
            poolStub.query.resolves({ rows: [] });

            chai.request(app)
                .get('/api/findings?is_false_positive=true')
                .end((err, res) => {
                    expect(res).to.have.status(200);
                    expect(res.body).to.be.an('array');
                    done();
                });
        });

        it('should respect limit parameter', (done) => {
            poolStub.query.resolves({ rows: [] });

            chai.request(app)
                .get('/api/findings?limit=10')
                .end((err, res) => {
                    expect(res).to.have.status(200);
                    done();
                });
        });

        it('should handle database errors', (done) => {
            poolStub.query.rejects(new Error('Database error'));

            chai.request(app)
                .get('/api/findings')
                .end((err, res) => {
                    expect(res).to.have.status(500);
                    expect(res.body).to.have.property('error');
                    done();
                });
        });
    });

    describe('GET /api/findings/stats/summary', () => {
        it('should return summary statistics (route ordering test)', (done) => {
            poolStub.query.resolves({
                rows: [
                    { severity: 'CRITICAL', total_count: 3, real_count: 3, false_positive_count: 0 },
                    { severity: 'HIGH', total_count: 5, real_count: 4, false_positive_count: 1 },
                    { severity: 'MEDIUM', total_count: 2, real_count: 2, false_positive_count: 0 },
                    { severity: 'LOW', total_count: 1, real_count: 1, false_positive_count: 0 },
                    { severity: 'INFO', total_count: 0, real_count: 0, false_positive_count: 0 }
                ]
            });

            chai.request(app)
                .get('/api/findings/stats/summary')
                .end((err, res) => {
                    expect(err).to.be.null;
                    expect(res).to.have.status(200);
                    expect(res.body).to.be.an('array');
                    expect(res.body).to.have.lengthOf(5);
                    expect(res.body[0]).to.have.property('severity');
                    expect(res.body[0]).to.have.property('total_count');
                    expect(res.body[0]).to.have.property('real_count');
                    done();
                });
        });

        it('should NOT match /:id route (critical route ordering fix)', (done) => {
            poolStub.query.resolves({
                rows: [
                    { severity: 'CRITICAL', total_count: 1, real_count: 1, false_positive_count: 0 }
                ]
            });

            chai.request(app)
                .get('/api/findings/stats/summary')
                .end((err, res) => {
                    // Should NOT be 404 (which would happen if /:id route matches first)
                    expect(res).to.not.have.status(404);
                    expect(res).to.have.status(200);
                    expect(res.body).to.be.an('array');
                    done();
                });
        });

        it('should filter by scan_id', (done) => {
            poolStub.query.resolves({ rows: [] });

            chai.request(app)
                .get('/api/findings/stats/summary?scan_id=1')
                .end((err, res) => {
                    expect(res).to.have.status(200);
                    done();
                });
        });
    });

    describe('GET /api/findings/:id', () => {
        it('should return finding details', (done) => {
            poolStub.query.resolves({
                rows: [{
                    id: 1,
                    finding_type: 'aws_access_key_id',
                    severity_name: 'CRITICAL',
                    location: '.env:1'
                }]
            });

            chai.request(app)
                .get('/api/findings/1')
                .end((err, res) => {
                    expect(res).to.have.status(200);
                    expect(res.body).to.have.property('id');
                    expect(res.body).to.have.property('finding_type');
                    done();
                });
        });

        it('should return 404 for non-existent finding', (done) => {
            poolStub.query.resolves({ rows: [] });

            chai.request(app)
                .get('/api/findings/99999')
                .end((err, res) => {
                    expect(res).to.have.status(404);
                    expect(res.body).to.have.property('error');
                    expect(res.body.error).to.equal('Finding not found');
                    done();
                });
        });
    });

    describe('PATCH /api/findings/:id', () => {
        it('should update finding as false positive', (done) => {
            poolStub.query.resolves({
                rows: [{
                    id: 1,
                    is_false_positive: true,
                    reviewed_by: 'test-user'
                }]
            });

            chai.request(app)
                .patch('/api/findings/1')
                .send({
                    is_false_positive: true,
                    reviewed_by: 'test-user',
                    notes: 'Test file - not real secret'
                })
                .end((err, res) => {
                    expect(res).to.have.status(200);
                    expect(res.body).to.have.property('is_false_positive');
                    expect(res.body.is_false_positive).to.be.true;
                    done();
                });
        });

        it('should return 400 when no fields to update', (done) => {
            chai.request(app)
                .patch('/api/findings/1')
                .send({})
                .end((err, res) => {
                    expect(res).to.have.status(400);
                    expect(res.body).to.have.property('error');
                    done();
                });
        });

        it('should return 404 for non-existent finding', (done) => {
            poolStub.query.resolves({ rows: [] });

            chai.request(app)
                .patch('/api/findings/99999')
                .send({
                    is_false_positive: true
                })
                .end((err, res) => {
                    expect(res).to.have.status(404);
                    done();
                });
        });
    });
});
