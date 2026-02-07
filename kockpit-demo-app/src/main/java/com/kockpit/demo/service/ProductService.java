package com.kockpit.demo.service;

import com.kockpit.demo.model.Product;
import com.kockpit.demo.repository.ProductRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.time.LocalDateTime;
import java.util.List;
import java.util.UUID;

/**
 * Product service - business logic for product management
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class ProductService {

    private final ProductRepository productRepository;

    public Product createProduct(Product product) {
        product.setId(UUID.randomUUID().toString());
        product.setCreatedAt(LocalDateTime.now());
        log.info("Creating product: {}", product.getName());
        return productRepository.save(product);
    }

    public Product getProduct(String id) {
        return productRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Product not found: " + id));
    }

    public List<Product> getAllProducts() {
        return productRepository.findAll();
    }

    public Product updateProduct(String id, Product product) {
        Product existing = getProduct(id);
        existing.setName(product.getName());
        existing.setPrice(product.getPrice());
        existing.setStock(product.getStock());
        existing.setUpdatedAt(LocalDateTime.now());
        log.info("Updating product: {}", id);
        return productRepository.save(existing);
    }

    public void deleteProduct(String id) {
        if (!productRepository.existsById(id)) {
            throw new RuntimeException("Product not found: " + id);
        }
        log.info("Deleting product: {}", id);
        productRepository.deleteById(id);
    }
}
