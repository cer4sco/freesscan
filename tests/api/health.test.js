const chai = require('chai');
const chaiHttp = require('chai-http');
const sinon = require('sinon');
const { expect } = chai;

chai.use(chaiHttp);

describe('Health API', () => {
    let app;
    let poolStub;

    beforeEach(() => {
        // Mock the database pool
        poolStub = {
            query: sinon.stub().resolves({ rows: [{ time: new Date() }] })
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

    describe('GET /health', () => {
        it('should return 200 OK when database is connected', (done) => {
            chai.request(app)
                .get('/health')
                .end((err, res) => {
                    expect(err).to.be.null;
                    expect(res).to.have.status(200);
                    expect(res.body).to.have.property('status');
                    expect(res.body.status).to.equal('healthy');
                    done();
                });
        });

        it('should return database connection status', (done) => {
            chai.request(app)
                .get('/health')
                .end((err, res) => {
                    expect(res.body).to.have.property('database');
                    expect(res.body.database).to.have.property('connected');
                    expect(res.body.database.connected).to.be.a('boolean');
                    done();
                });
        });

        it('should handle database errors gracefully', (done) => {
            poolStub.query.rejects(new Error('Database connection failed'));

            chai.request(app)
                .get('/health')
                .end((err, res) => {
                    expect(res).to.have.status(503);  // Service Unavailable when DB fails
                    expect(res.body).to.have.property('status');
                    expect(res.body.status).to.equal('unhealthy');
                    expect(res.body).to.have.property('database');
                    expect(res.body.database.connected).to.be.false;
                    done();
                });
        });
    });
});
