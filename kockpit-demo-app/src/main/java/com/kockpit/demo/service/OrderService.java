package com.kockpit.demo.service;

import com.kockpit.demo.model.Order;
import com.kockpit.demo.model.OrderStatus;
import com.kockpit.demo.repository.OrderRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.time.LocalDateTime;
import java.util.List;
import java.util.UUID;

/**
 * Order service - business logic for order management
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class OrderService {

    private final OrderRepository orderRepository;

    public Order createOrder(Order order) {
        order.setId(UUID.randomUUID().toString());
        order.setStatus(OrderStatus.CREATED);
        order.setCreatedAt(LocalDateTime.now());
        log.info("Creating order: {} for customer: {}", order.getId(), order.getCustomerId());
        return orderRepository.save(order);
    }

    public Order getOrder(String id) {
        return orderRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Order not found: " + id));
    }

    public List<Order> getAllOrders() {
        return orderRepository.findAll();
    }

    public Order cancelOrder(String id, String reason) {
        Order order = getOrder(id);
        if (order.getStatus() == OrderStatus.DELIVERED) {
            throw new RuntimeException("Cannot cancel delivered order");
        }
        order.setStatus(OrderStatus.CANCELLED);
        order.setCancelReason(reason);
        order.setCancelledAt(LocalDateTime.now());
        order.setUpdatedAt(LocalDateTime.now());
        log.info("Cancelling order: {} - Reason: {}", id, reason);
        return orderRepository.save(order);
    }

    public Order shipOrder(String id, String trackingNumber) {
        Order order = getOrder(id);
        if (order.getStatus() != OrderStatus.CREATED && order.getStatus() != OrderStatus.CONFIRMED) {
            throw new RuntimeException("Order cannot be shipped in current status: " + order.getStatus());
        }
        order.setStatus(OrderStatus.SHIPPED);
        order.setTrackingNumber(trackingNumber);
        order.setShippedAt(LocalDateTime.now());
        order.setUpdatedAt(LocalDateTime.now());
        log.info("Shipping order: {} - Tracking: {}", id, trackingNumber);
        return orderRepository.save(order);
    }

    public Order deliverOrder(String id) {
        Order order = getOrder(id);
        if (order.getStatus() != OrderStatus.SHIPPED) {
            throw new RuntimeException("Order must be shipped before delivery");
        }
        order.setStatus(OrderStatus.DELIVERED);
        order.setDeliveredAt(LocalDateTime.now());
        order.setUpdatedAt(LocalDateTime.now());
        log.info("Delivering order: {}", id);
        return orderRepository.save(order);
    }
}
