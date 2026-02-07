package com.kockpit.demo.controller;

import com.kockpit.demo.model.ApiResponse;
import com.kockpit.demo.model.Product;
import com.kockpit.demo.service.ProductService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.kockpit.audit.annotation.AuditAttribute;
import org.kockpit.audit.annotation.Audited;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;

import java.util.List;

/**
 * Product REST Controller
 * All operations are automatically audited via @Audited annotation
 */
@RestController
@RequestMapping("/api/products")
@RequiredArgsConstructor
@Slf4j
@Audited
public class ProductController {

    private final ProductService productService;

    /**
     * List all products
     * Audit action: LIST_PRODUCTS
     */
    @GetMapping
    public ApiResponse<List<Product>> listProducts() {
        log.info("Listing all products");
        List<Product> products = productService.getAllProducts();
        return ApiResponse.success(products);
    }

    /**
     * Get product by ID
     * Audit action: GET_PRODUCT
     */
    @GetMapping("/{id}")
    public ApiResponse<Product> getProduct(
            @PathVariable @AuditAttribute(key = "productId") String id) {
        log.info("Getting product: {}", id);
        Product product = productService.getProduct(id);
        return ApiResponse.success(product);
    }

    /**
     * Create new product
     * Audit action: CREATE_PRODUCT
     */
    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public ApiResponse<Product> createProduct(
            @RequestBody @AuditAttribute(key = "product") Product product) {
        log.info("Creating product: {}", product.getName());
        Product created = productService.createProduct(product);
        return ApiResponse.success(created, "Product created successfully");
    }

    /**
     * Update existing product
     * Audit action: UPDATE_PRODUCT
     */
    @PutMapping("/{id}")
    public ApiResponse<Product> updateProduct(
            @PathVariable @AuditAttribute(key = "productId") String id,
            @RequestBody @AuditAttribute(key = "productUpdates") Product product) {
        log.info("Updating product: {}", id);
        Product updated = productService.updateProduct(id, product);
        return ApiResponse.success(updated, "Product updated successfully");
    }

    /**
     * Delete product
     * Audit action: DELETE_PRODUCT
     */
    @DeleteMapping("/{id}")
    public ApiResponse<Void> deleteProduct(
            @PathVariable @AuditAttribute(key = "productId") String id) {
        log.info("Deleting product: {}", id);
        productService.deleteProduct(id);
        return ApiResponse.success(null, "Product deleted successfully");
    }

    /**
     * Exception handler for product-related errors
     */
    @ExceptionHandler(RuntimeException.class)
    @ResponseStatus(HttpStatus.BAD_REQUEST)
    public ApiResponse<Void> handleException(RuntimeException ex) {
        log.error("Error in product operation", ex);
        return ApiResponse.error(ex.getMessage());
    }
}
