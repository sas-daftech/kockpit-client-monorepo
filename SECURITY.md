# Security Policy

## Reporting Security Vulnerabilities

If you discover a security vulnerability in this project, please report it by contacting the maintainers directly. Do not create public GitHub issues for security vulnerabilities.

## Security Best Practices

### Credentials Management

**CRITICAL**: This repository contains demo applications with example configurations. Follow these security practices:

#### 1. Environment Variables

**NEVER commit credentials to version control**. Always use environment variables:

```bash
# Required environment variables
export KOCKPIT_USERNAME=your_username
export KOCKPIT_PASSWORD=your_secure_password

# For production, use strong passwords
export KOCKPIT_PASSWORD=$(openssl rand -base64 32)
```

#### 2. Application Configuration

The `kockpit-demo-app/src/main/resources/application.yaml` requires the `KOCKPIT_PASSWORD` environment variable:

```yaml
kockpit:
  audit:
    backend:
      username: ${KOCKPIT_USERNAME:user}
      password: ${KOCKPIT_PASSWORD}  # NO default value - must be set explicitly
```

#### 3. Production Deployment

For production environments:

- ✅ Use **strong, unique passwords** (minimum 16 characters)
- ✅ Store credentials in **secret management systems** (AWS Secrets Manager, Azure Key Vault, HashiCorp Vault)
- ✅ Enable **TLS/SSL** for all HTTP communications
- ✅ Consider migrating to **OAuth2 or JWT** authentication instead of Basic Auth
- ✅ Implement **rate limiting** and **IP whitelisting**
- ✅ Enable **audit logging** for all authentication attempts
- ✅ Rotate credentials regularly

### Network Security

#### 1. TLS/SSL Configuration

For production, configure HTTPS:

```yaml
# application-prod.yaml
server:
  ssl:
    enabled: true
    key-store: classpath:keystore.p12
    key-store-password: ${KEYSTORE_PASSWORD}
    key-store-type: PKCS12
```

#### 2. Firewall Rules

- Backend API (port 8080): **Internal network only**
- OpenSearch (port 9200): **Localhost only** or secured network
- Kafka (port 9092): **Internal network only**
- Demo App (port 8091): **Only expose to trusted networks**

### OpenSearch Security

#### 1. Enable Security Plugin

The default OpenSearch configuration in this repo has **security disabled** for development. For production:

```yaml
# opensearch.yml
plugins.security.disabled: false
plugins.security.ssl.http.enabled: true
```

#### 2. Access Control

- Enable OpenSearch Security Plugin
- Create role-based access control (RBAC)
- Use dedicated service accounts with minimal permissions

### Secrets in Git History

If credentials were accidentally committed:

1. **Immediately rotate** the exposed credentials
2. **Rewrite Git history** to remove secrets:
   ```bash
   git filter-branch --force --index-filter \
     "git rm --cached --ignore-unmatch path/to/file" \
     --prune-empty --tag-name-filter cat -- --all
   ```
3. **Force push** after coordinating with team (destructive operation)
4. Consider using tools like:
   - [git-secrets](https://github.com/awslabs/git-secrets)
   - [GitGuardian](https://www.gitguardian.com/)
   - [truffleHog](https://github.com/trufflesecurity/trufflehog)

### Docker Security

#### 1. Image Security

- Use official base images from trusted sources
- Scan images for vulnerabilities: `docker scan kockpit-backend`
- Keep base images updated
- Use minimal images (alpine, distroless)

#### 2. Container Runtime

```yaml
# docker-compose.yml security hardening
services:
  opensearch:
    security_opt:
      - no-new-privileges:true
    read_only: true
    tmpfs:
      - /tmp
```

### Application Security

#### 1. Input Validation

The demo application validates input using Spring Boot Validation:

```java
@Valid @RequestBody ProductRequest request
```

Ensure all inputs are validated and sanitized.

#### 2. SQL Injection Prevention

This application uses in-memory repositories. If migrating to a database:

- Use **parameterized queries** or **ORM frameworks** (JPA/Hibernate)
- **Never** concatenate user input into SQL strings

#### 3. XSS Prevention

- Escape all user-generated content before rendering
- Use Content Security Policy (CSP) headers
- Sanitize HTML input

#### 4. CSRF Protection

Spring Security CSRF protection is enabled by default. Keep it enabled for production:

```yaml
spring:
  security:
    csrf:
      enabled: true
```

### Monitoring and Auditing

#### 1. Security Events

Monitor these security-relevant events:

- Authentication failures
- Authorization failures
- Unusual API usage patterns
- Configuration changes

#### 2. Log Sensitive Data

**NEVER log**:
- Passwords or tokens
- Credit card numbers
- Personal identifiable information (PII)
- API keys or secrets

Use the `kockpit-obfuscation` module for sensitive data handling.

### Dependency Security

#### 1. Vulnerability Scanning

Regularly scan dependencies for vulnerabilities:

```bash
# Maven dependency check
mvn dependency-check:check

# OWASP Dependency Check
mvn org.owasp:dependency-check-maven:check
```

#### 2. Keep Dependencies Updated

- Monitor security advisories for Spring Boot, OpenSearch, and Kafka
- Update dependencies promptly when security patches are released
- Test thoroughly before deploying updates

### Development vs Production

| Security Aspect | Development | Production |
|----------------|-------------|------------|
| Basic Auth Password | Environment variable | Secret management system |
| TLS/SSL | Optional | **Required** |
| OpenSearch Security | Disabled | **Enabled with authentication** |
| Firewall | Open localhost | **Strict whitelist** |
| Logging Level | DEBUG | INFO or WARN |
| Actuator Endpoints | All exposed | Limited, secured |

## Security Checklist for Production

Before deploying to production:

- [ ] All credentials stored in secret management system
- [ ] TLS/SSL enabled for all services
- [ ] OpenSearch Security Plugin enabled and configured
- [ ] Firewall rules configured (least privilege)
- [ ] Authentication mechanism reviewed (consider OAuth2/JWT)
- [ ] Rate limiting enabled
- [ ] Security headers configured (HSTS, CSP, X-Frame-Options)
- [ ] Dependency vulnerabilities scanned and addressed
- [ ] Security monitoring and alerting configured
- [ ] Incident response plan documented
- [ ] Access logs enabled and retained
- [ ] Regular security audits scheduled

## GitGuardian Alerts

If you receive a GitGuardian alert about exposed secrets:

1. **Rotate the credentials immediately**
2. **Review the commit** that exposed the secret
3. **Update configuration** to use environment variables
4. **Commit the fix** to the repository
5. **Consider rewriting Git history** if the secret is highly sensitive
6. **Monitor** for unauthorized access using the exposed credentials

## Contact

For security concerns, contact the repository maintainers.

---

**Remember**: Security is not a one-time task but an ongoing process. Stay vigilant and keep your systems updated.
