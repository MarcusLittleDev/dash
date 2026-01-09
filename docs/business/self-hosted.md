# Self-Hosted Enterprise Edition

## Overview

Dash can be deployed on customer infrastructure for organizations requiring:
- **Data sovereignty** - Data never leaves customer environment
- **Regulatory compliance** - HIPAA, PCI-DSS, FedRAMP, GDPR
- **Security requirements** - Behind corporate firewall
- **Customization** - Deep integration with internal systems
- **Cost optimization** - Heavy usage scenarios

## Target Market

### Primary Customers

**Healthcare Providers**
- HIPAA compliance requirements
- Patient data must stay on-premise
- Integration with existing EHR systems
- Annual IT budget: $50K-500K

**Financial Institutions**
- PCI-DSS compliance
- SOX compliance requirements
- Data residency regulations
- Annual compliance budget: $100K-1M

**Government Agencies**
- FedRAMP requirements
- ITAR compliance
- Air-gapped environments
- Contract values: $100K-5M

**Large Enterprises**
- Internal data policies
- Existing infrastructure investment
- Custom integration needs
- IT budget: $50K-500K per system

### Market Opportunity

- Self-hosted customers pay 2.5-5x cloud pricing
- 10 self-hosted customers @ $2K/month = $240K ARR
- Higher LTV (3-5 year contracts typical)
- Lower infrastructure costs (customer provides)
- Professional services revenue stream

---

## Deployment Options

### Option 1: Docker Compose

**Best for:** Small to medium deployments (1-100 users)

**Installation:**
```bash
# Download package
wget https://releases.dash.app/enterprise/dash-enterprise-v1.0.0.tar.gz
tar -xzf dash-enterprise-v1.0.0.tar.gz
cd dash-enterprise

# Configure
cp .env.example .env
nano .env  # Edit configuration

# Generate secrets
./scripts/generate-secrets.sh

# Start services
docker-compose up -d

# Run migrations
docker-compose exec dash bin/dash eval "Dash.Release.migrate"

# Create admin user
docker-compose exec dash bin/dash eval "Dash.Release.create_admin"

# Access at https://your-domain.com
```

**Components:**
- Dash application (Elixir/Phoenix)
- TimescaleDB (PostgreSQL 16 + extension)
- Redis (caching and job queue)
- Nginx (reverse proxy, SSL termination)

---

### Option 2: Kubernetes

**Best for:** Large deployments (100+ users), high availability

**Installation:**
```bash
# Add Dash Helm repository
helm repo add dash https://charts.dash.app
helm repo update

# Install
helm install dash dash/dash-enterprise \
  --namespace dash-production \
  --create-namespace \
  --set license.key=$LICENSE_KEY \
  --set database.host=postgres.internal.company.com \
  --set database.password=$DB_PASSWORD \
  --set ingress.host=dash.company.com \
  --set replicas=3

# Verify
kubectl get pods -n dash-production
```

**Features:**
- Auto-scaling (HPA)
- Rolling updates
- BEAM clustering
- High availability
- Load balancing

---

### Option 3: Air-Gapped Installation

**Best for:** Government, secure environments, no internet

**Package Contents:**
- Pre-built Docker images (2.5 GB)
- All dependencies bundled
- Offline license validation
- Complete documentation (PDF)
- Installation scripts
- Backup/restore utilities

**Installation:**
```bash
# Transfer package (USB, secure transfer)
# Verify integrity
gpg --verify VERIFICATION.sig dash-enterprise-airgapped-v1.0.0.tar.gz

# Extract
tar -xzf dash-enterprise-airgapped-v1.0.0.tar.gz
cd dash-enterprise-airgapped

# Load Docker images
./scripts/load-images.sh

# Configure
cp config/.env.example .env
nano .env

# Install
sudo ./install.sh

# Access at configured hostname
```

---

## Customer Integration

### Bring Your Own Database

Dash supports customer-managed PostgreSQL:

**Requirements:**
- PostgreSQL 14+
- TimescaleDB extension
- SSL/TLS required for production
- Minimum 4 CPU, 16 GB RAM recommended

**Configuration:**
```bash
# .env
DATABASE_URL=ecto://user:pass@postgres.company.com:5432/dash_prod
DATABASE_SSL=true
DATABASE_CA_CERT=/path/to/ca-cert.pem
DATABASE_CLIENT_CERT=/path/to/client-cert.pem
DATABASE_CLIENT_KEY=/path/to/client-key.pem
```

### Authentication Integration

**Supported Methods:**
- SAML 2.0 (Okta, Azure AD, OneLogin)
- LDAP/Active Directory
- OAuth 2.0 (custom providers)

**SAML Configuration:**
```yaml
# config/self-hosted.yaml
authentication:
  saml:
    enabled: true
    idp_metadata_url: https://sso.company.com/metadata
    sp_entity_id: https://dash.company.com
    attributes:
      email: "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress"
      name: "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/name"
    role_mapping:
      "dash-admins": "admin"
      "dash-users": "member"
```

**LDAP Configuration:**
```yaml
authentication:
  ldap:
    enabled: true
    host: ldap.company.com
    port: 636
    ssl: true
    base_dn: "dc=company,dc=com"
    bind_dn: "cn=dash-service,ou=services,dc=company,dc=com"
    user_search:
      base: "ou=users,dc=company,dc=com"
      filter: "(&(objectClass=person)(mail=%{email}))"
```

### Storage Integration

**Supported Backends:**
- AWS S3
- MinIO (self-hosted S3-compatible)
- Azure Blob Storage
- Google Cloud Storage
- Local filesystem (dev/test only)

**MinIO Example:**
```bash
# .env
STORAGE_ADAPTER=s3
STORAGE_ENDPOINT=https://minio.company.com
STORAGE_BUCKET=dash-files
STORAGE_ACCESS_KEY=minio-access-key
STORAGE_SECRET_KEY=minio-secret-key
STORAGE_PATH_STYLE=true
```

### Monitoring Integration

**Prometheus Metrics:**
- Exposed on port 9090
- Custom Dash metrics
- BEAM VM metrics
- Database connection pool stats

**Syslog Integration:**
```bash
# .env
SYSLOG_ENABLED=true
SYSLOG_HOST=syslog.company.com
SYSLOG_PORT=514
SYSLOG_PROTOCOL=tcp
```

**Supported Monitoring Systems:**
- Prometheus + Grafana
- Datadog
- New Relic
- Splunk
- ELK Stack

---

## Licensing

### License Tiers

#### Self-Hosted Starter - $499/month

**Includes:**
- Up to 25 users
- 50 pipelines
- 100 GB storage
- Community forum support
- Quarterly updates
- Annual contract required

**Target:** Small teams, departmental deployments

#### Self-Hosted Professional - $1,999/month

**Includes:**
- Up to 100 users
- Unlimited pipelines
- 500 GB storage
- Email support (8x5, 24-hour response)
- Custom branding (logo, colors)
- SSO integration (SAML/LDAP)
- Monthly updates
- Annual contract

**Target:** Production deployments, growing companies

#### Self-Hosted Enterprise - $4,999+/month

**Includes:**
- Unlimited users
- Unlimited pipelines
- Custom storage (negotiated)
- 24/7 phone + email support (1-hour response)
- Dedicated customer success manager
- Custom features & integrations
- White-label option
- SLA: 99.9% uptime guarantee
- Professional services (40 hours/year included)
- On-site training available
- Weekly security updates
- Multi-year contracts available

**Target:** Large enterprises, regulated industries, government

### Add-Ons

**Air-Gapped Installation:**
- One-time setup: $2,000
- Offline installer package
- USB delivery option

**Professional Services:**
- Rate: $250/hour
- Custom integrations
- Data migration
- Performance tuning
- Security audits

**High Availability Setup:**
- HA setup assistance: $5,000 one-time
- Kubernetes deployment: $3,000 one-time
- Disaster recovery: $2,000 one-time

---

## License Validation

### How Licensing Works

**License Format:**
- JWT-based license key
- Signed by Dash (verified with embedded public key)
- Contains: tier, user limits, features, expiration

**Validation Behavior:**
- Non-blocking (soft limits)
- Warnings displayed in admin UI
- Grace period after expiration (30 days)
- Email notifications to admins

**What's Enforced:**
- Feature access (SSO, custom branding, etc.)
- Support level visibility
- Update channel access

**What's Not Blocked:**
- Core functionality continues
- Existing users can still access
- Pipelines continue running
- Dashboards remain accessible

### License Management UI

Accessible at: `/admin/license`

**Features:**
- View license details
- Check expiration
- Monitor usage vs limits
- Update license key
- Contact support

---

## Implementation Roadmap

### Phase 1: Docker Foundation (Month 12-13)
- Docker images and Compose setup
- License validation system
- Installation scripts
- Basic documentation
- Beta release (2-3 customers)

### Phase 2: Enterprise Features (Month 14-15)
- SAML/LDAP authentication
- Custom branding
- Advanced monitoring
- Security hardening
- Professional tier launch

### Phase 3: Kubernetes Support (Month 16-17)
- Helm charts
- HA configurations
- BEAM clustering in K8s
- Auto-scaling
- Enterprise tier launch

### Phase 4: Air-Gapped (Month 18-19)
- Offline installer
- Bundled dependencies
- Government compliance
- FedRAMP documentation
- Federal sales launch

---

## Pricing Strategy

### Cloud vs. Self-Hosted Comparison

| Feature | Cloud SaaS | Self-Hosted | Premium |
|---------|-----------|-------------|---------|
| **Pricing (Pro)** | $199/mo | $1,999/mo | 10x |
| **Data Location** | Dash servers | Customer | - |
| **Updates** | Automatic | Controlled | - |
| **Customization** | Limited | Full | - |
| **Compliance** | Our certs | Customer | - |
| **Support** | Email/chat | Phone 24/7 | - |

### Why Customers Pay More

1. **Data Sovereignty** - Priceless for some industries
2. **Compliance** - Required by regulations
3. **No Data Egress** - Save at scale
4. **Integration** - With existing systems
5. **Customization** - White-label, custom features

### Target Customer Economics

- Healthcare: $50K-500K/year IT budget
- Finance: $100K-1M/year compliance
- Government: $100K-5M/year contracts
- Enterprise: $50K-500K/year per system

---

## Revenue Projections

### Year 1 (Launch Month 12)
- 3 Professional: $5,997/mo = $72K ARR
- 1 Enterprise: $4,999/mo = $60K ARR
- **Total:** $132K ARR (4 customers)

### Year 2
- 15 Professional: $29,985/mo = $360K ARR
- 5 Enterprise: $24,995/mo = $300K ARR
- **Total:** $660K ARR (20 customers)

### Year 3
- 30 Professional: $720K ARR
- 15 Enterprise: $900K ARR
- **Total:** $1.62M ARR (45 customers)

### Combined Revenue (Cloud + Self-Hosted)

**Year 3 Total:**
- Cloud: $2M ARR (500 customers @ $4K avg)
- Self-Hosted: $1.6M ARR (45 customers @ $36K avg)
- **Total: $3.6M ARR**

Self-hosted represents 45% of revenue from just 8% of customers!

---

## Sales Strategy

### Target Customers

**Ideal Customer Profile:**
- 100-10,000 employees
- Regulated industry (healthcare, finance, government)
- Existing data residency requirements
- IT budget >$50K/year
- Multiple internal systems to integrate

### Sales Cycle

**Timeline:** 3-6 months average

**Stages:**
1. Discovery (2 weeks)
2. Proof of concept (4 weeks)
3. Security review (2-4 weeks)
4. Procurement (4-8 weeks)
5. Deployment (2-4 weeks)

### Objection Handling

**"Too expensive vs cloud"**
- Show TCO including compliance costs
- Data egress savings at scale
- Customization value
- No vendor lock-in

**"Operational complexity"**
- Professional services included
- Managed service option
- Excellent documentation
- 24/7 support

**"Why not build ourselves?"**
- $50K+ dev cost
- $5K+/month maintenance
- Ongoing feature development
- Security updates
- Support burden

---

## Success Metrics

### Customer Success Indicators

- License renewal rate >90%
- Support ticket volume <5/month
- Feature adoption >60%
- Customer satisfaction (NPS) >50

### Business Metrics

- Sales cycle: <6 months
- CAC payback: <12 months
- Gross margin: >80%
- Expansion revenue: >20% annually

---

## Support Model

### Starter Tier
- Community forum
- Email (48-hour response)
- Quarterly updates
- Knowledge base access

### Professional Tier
- Email support (24-hour response, 8x5)
- Phone support (business hours)
- Monthly updates
- Slack channel (optional, +$500/mo)

### Enterprise Tier
- 24/7 phone + email (1-hour response)
- Dedicated success manager
- Weekly security updates
- Monthly check-ins
- Slack channel included
- On-site visits (2/year)

---

## Documentation Provided

### Installation Guides
- Docker Compose setup (30 pages)
- Kubernetes deployment (40 pages)
- Air-gapped installation (50 pages)

### Administration
- User management (20 pages)
- Backup/restore (15 pages)
- Monitoring setup (25 pages)
- Troubleshooting (30 pages)

### Security
- Hardening guide (40 pages)
- Compliance checklist (HIPAA, PCI-DSS, etc.)
- Audit logging (10 pages)
- Incident response (15 pages)

### Integration
- SAML/LDAP setup (25 pages)
- Storage backends (15 pages)
- Monitoring systems (20 pages)
- Custom integrations (30 pages)

---

## Competitive Advantage

### Why Dash Self-Hosted Wins

**vs. Cloud-Only Competitors:**
- We offer both cloud and self-hosted
- Regulatory compliance unlocks new markets
- Data sovereignty = no lock-in concerns

**vs. Open Source:**
- Commercial support
- Enterprise features
- Security updates
- Professional documentation

**vs. Building In-House:**
- 10x faster to deploy
- Lower TCO
- Ongoing innovation
- Proven at scale

---

## Next Steps

### For Customers

**Interested in Self-Hosted?**

1. **Contact sales:** sales@dash.app
2. **Schedule demo:** 30-minute overview
3. **Proof of concept:** 30-day trial
4. **Pilot deployment:** 2-3 months
5. **Full deployment:** After pilot success

### For Dash Team

**Preparing for Launch:**

1. **Month 12:** Docker images ready
2. **Month 13:** Beta customer pilots
3. **Month 14:** SAML/LDAP integration
4. **Month 15:** Professional tier launch
5. **Month 16:** Kubernetes ready
6. **Month 17:** Enterprise tier launch
7. **Month 18:** Air-gapped ready
8. **Month 19:** Government launch

---

**Questions?** Contact: enterprise@dash.app

**Documentation:** https://docs.dash.app/self-hosted

**Support:** https://support.dash.app
