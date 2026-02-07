package com.kockpit.demo;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

/**
 * Kockpit Demo Application
 *
 * This application demonstrates the integration of kockpit-audit-sdk
 * for automatic audit trail generation of REST API operations.
 *
 * Features:
 * - Product management (CRUD)
 * - Order management (lifecycle tracking)
 * - Automatic audit logging via @Audited annotations
 * - Integration with kockpit-backend for audit storage
 */
@SpringBootApplication
public class DemoApplication {

    public static void main(String[] args) {
        SpringApplication.run(DemoApplication.class, args);
    }
}
