package com.kockpit.demo.repository;

import com.kockpit.demo.model.Order;
import org.springframework.stereotype.Repository;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.concurrent.ConcurrentHashMap;

/**
 * In-memory order repository for demo purposes
 */
@Repository
public class OrderRepository {

    private final Map<String, Order> storage = new ConcurrentHashMap<>();

    public Order save(Order order) {
        storage.put(order.getId(), order);
        return order;
    }

    public Optional<Order> findById(String id) {
        return Optional.ofNullable(storage.get(id));
    }

    public List<Order> findAll() {
        return new ArrayList<>(storage.values());
    }

    public void deleteById(String id) {
        storage.remove(id);
    }

    public boolean existsById(String id) {
        return storage.containsKey(id);
    }
}
