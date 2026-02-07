package com.kockpit.demo.controller;

import com.kockpit.demo.model.ApiResponse;
import com.kockpit.demo.model.Order;
import com.kockpit.demo.service.OrderService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.kockpit.audit.annotation.AuditAttribute;
import org.kockpit.audit.annotation.Audited;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

/**
 * Order REST Controller
 * All operations are automatically audited via @Audited annotation
 */
@RestController
@RequestMapping("/api/orders")
@RequiredArgsConstructor
@Slf4j
@Audited
public class OrderController {

    private final OrderService orderService;

    /**
     * List all orders
     * Audit action: LIST_ORDERS
     */
    @GetMapping
    public ApiResponse<List<Order>> listOrders() {
        log.info("Listing all orders");
        List<Order> orders = orderService.getAllOrders();
        return ApiResponse.success(orders);
    }

    /**
     * Get order by ID
     * Audit action: GET_ORDER
     */
    @GetMapping("/{id}")
    public ApiResponse<Order> getOrder(
            @PathVariable @AuditAttribute(key = "orderId") String id) {
        log.info("Getting order: {}", id);
        Order order = orderService.getOrder(id);
        return ApiResponse.success(order);
    }

    /**
     * Create new order
     * Audit action: CREATE_ORDER
     */
    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public ApiResponse<Order> createOrder(
            @RequestBody @AuditAttribute(key = "order") Order order) {
        log.info("Creating order for customer: {}", order.getCustomerId());
        Order created = orderService.createOrder(order);
        return ApiResponse.success(created, "Order created successfully");
    }

    /**
     * Cancel order
     * Audit action: CANCEL_ORDER
     */
    @PostMapping("/{id}/cancel")
    public ApiResponse<Order> cancelOrder(
            @PathVariable @AuditAttribute(key = "orderId") String id,
            @RequestBody Map<String, String> payload) {
        String reason = payload.getOrDefault("reason", "No reason provided");
        log.info("Cancelling order: {} - Reason: {}", id, reason);
        Order cancelled = orderService.cancelOrder(id, reason);
        return ApiResponse.success(cancelled, "Order cancelled successfully");
    }

    /**
     * Ship order
     * Audit action: SHIP_ORDER
     */
    @PostMapping("/{id}/ship")
    public ApiResponse<Order> shipOrder(
            @PathVariable @AuditAttribute(key = "orderId") String id,
            @RequestBody Map<String, String> payload) {
        String trackingNumber = payload.get("trackingNumber");
        if (trackingNumber == null || trackingNumber.isEmpty()) {
            throw new RuntimeException("Tracking number is required");
        }
        log.info("Shipping order: {} - Tracking: {}", id, trackingNumber);
        Order shipped = orderService.shipOrder(id, trackingNumber);
        return ApiResponse.success(shipped, "Order shipped successfully");
    }

    /**
     * Deliver order
     * Audit action: DELIVER_ORDER
     */
    @PostMapping("/{id}/deliver")
    public ApiResponse<Order> deliverOrder(
            @PathVariable @AuditAttribute(key = "orderId") String id) {
        log.info("Delivering order: {}", id);
        Order delivered = orderService.deliverOrder(id);
        return ApiResponse.success(delivered, "Order delivered successfully");
    }

    /**
     * Exception handler for order-related errors
     */
    @ExceptionHandler(RuntimeException.class)
    @ResponseStatus(HttpStatus.BAD_REQUEST)
    public ApiResponse<Void> handleException(RuntimeException ex) {
        log.error("Error in order operation", ex);
        return ApiResponse.error(ex.getMessage());
    }
}
