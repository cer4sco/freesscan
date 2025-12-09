const chai = require('chai');
const chaiHttp = require('chai-http');
const sinon = require('sinon');
const { expect } = chai;

chai.use(chaiHttp);

describe('Scans API', () => {
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

    describe('GET /api/scans', () => {
        it('should return array of scans', (done) => {
            poolStub.query.resolves({
                rows: [
                    {
                        id: 1,
                        scan_type: 'secret',
                        target: '/test/repo',
                        status: 'completed',
                        findings_count: 5
                    }
                ]
            });

            chai.request(app)
                .get('/api/scans')
                .end((err, res) => {
                    expect(err).to.be.null;
                    expect(res).to.have.status(200);
                    expect(res.body).to.be.an('array');
                    expect(res.body).to.have.lengthOf(1);
                    expect(res.body[0]).to.have.property('id');
                    expect(res.body[0]).to.have.property('scan_type');
                    done();
                });
        });

        it('should return empty array when no scans exist', (done) => {
            poolStub.query.resolves({ rows: [] });

            chai.request(app)
                .get('/api/scans')
                .end((err, res) => {
                    expect(res).to.have.status(200);
                    expect(res.body).to.be.an('array');
                    expect(res.body).to.have.lengthOf(0);
                    done();
                });
        });

        it('should handle database errors', (done) => {
            poolStub.query.rejects(new Error('Database error'));

            chai.request(app)
                .get('/api/scans')
                .end((err, res) => {
                    expect(res).to.have.status(500);
                    expect(res.body).to.have.property('error');
                    done();
                });
        });
    });

    describe('GET /api/scans/:id', () => {
        it('should return scan details with findings', (done) => {
            poolStub.query.onFirstCall().resolves({
                rows: [{
                    id: 1,
                    scan_type: 'secret',
                    target: '/test/repo',
                    status: 'completed'
                }]
            });

            poolStub.query.onSecondCall().resolves({
                rows: [
                    {
                        id: 1,
                        finding_type: 'aws_access_key_id',
                        severity_name: 'CRITICAL'
                    }
                ]
            });

            chai.request(app)
                .get('/api/scans/1')
                .end((err, res) => {
                    expect(res).to.have.status(200);
                    expect(res.body).to.have.property('scan');
                    expect(res.body).to.have.property('findings');
                    expect(res.body.scan.id).to.equal(1);
                    expect(res.body.findings).to.be.an('array');
                    done();
                });
        });

        it('should return 404 for non-existent scan', (done) => {
            poolStub.query.resolves({ rows: [] });

            chai.request(app)
                .get('/api/scans/99999')
                .end((err, res) => {
                    expect(res).to.have.status(404);
                    expect(res.body).to.have.property('error');
                    expect(res.body.error).to.equal('Scan not found');
                    done();
                });
        });
    });

    describe('POST /api/scans', () => {
        it('should create new scan with valid data', (done) => {
            poolStub.query.resolves({
                rows: [{
                    id: 1,
                    scan_type: 'secret',
                    target: '/test/repo',
                    status: 'running',
                    created_by: 'test-user'
                }]
            });

            chai.request(app)
                .post('/api/scans')
                .send({
                    scan_type: 'secret',
                    target: '/test/repo',
                    created_by: 'test-user'
                })
                .end((err, res) => {
                    expect(res).to.have.status(201);
                    expect(res.body).to.have.property('id');
                    expect(res.body.status).to.equal('running');
                    expect(res.body.scan_type).to.equal('secret');
                    done();
                });
        });

        it('should require scan_type', (done) => {
            chai.request(app)
                .post('/api/scans')
                .send({
                    target: '/test/repo'
                })
                .end((err, res) => {
                    expect(res).to.have.status(400);
                    expect(res.body).to.have.property('error');
                    done();
                });
        });

        it('should require target', (done) => {
            chai.request(app)
                .post('/api/scans')
                .send({
                    scan_type: 'secret'
                })
                .end((err, res) => {
                    expect(res).to.have.status(400);
                    expect(res.body).to.have.property('error');
                    done();
                });
        });

        it('should handle empty request body', (done) => {
            chai.request(app)
                .post('/api/scans')
                .send({})
                .end((err, res) => {
                    expect(res).to.have.status(400);
                    done();
                });
        });
    });
});
