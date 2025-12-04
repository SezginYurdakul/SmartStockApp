# Elasticsearch Integration

This project is configured and ready to use Elasticsearch with Laravel Scout.

## Post-Installation Steps

### 1. Install Laravel Scout and Elasticsearch Driver

Connect to the backend container and install the required packages:

```bash
docker compose exec php sh
composer require laravel/scout
composer require matchish/laravel-scout-elasticsearch
exit
```

### 2. Scout Configuration

Publish the Scout configuration files:

```bash
docker compose exec php php artisan vendor:publish --provider="Laravel\Scout\ScoutServiceProvider"
docker compose exec php php artisan vendor:publish --provider="Matchish\ScoutElasticSearch\ScoutElasticSearchServiceProvider"
```

### 3. Add Searchable Trait to Models

Add the `Searchable` trait to models you want to make searchable:

```php
<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Laravel\Scout\Searchable;

class Product extends Model
{
    use Searchable;

    /**
     * Get the indexable data array for the model.
     *
     * @return array
     */
    public function toSearchableArray()
    {
        return [
            'id' => $this->id,
            'name' => $this->name,
            'description' => $this->description,
            'sku' => $this->sku,
            'price' => $this->price,
            'stock_quantity' => $this->stock_quantity,
        ];
    }

    /**
     * Get the name of the index associated with the model.
     *
     * @return string
     */
    public function searchableAs()
    {
        return 'products_index';
    }
}
```

### 4. Create Indices

Import existing data to Elasticsearch:

```bash
# Index all products
docker compose exec php php artisan scout:import "App\Models\Product"

# Flush the index
docker compose exec php php artisan scout:flush "App\Models\Product"
```

### 5. Using Search

Example of implementing search in a controller:

```php
use App\Models\Product;

class ProductController extends Controller
{
    public function search(Request $request)
    {
        $query = $request->input('q');

        $products = Product::search($query)
            ->paginate(20);

        return response()->json($products);
    }

    // Search with filters
    public function advancedSearch(Request $request)
    {
        $products = Product::search($request->input('q'))
            ->where('stock_quantity', '>', 0)
            ->orderBy('created_at', 'desc')
            ->paginate(20);

        return response()->json($products);
    }
}
```

### 6. Automatic Synchronization

Scout automatically updates Elasticsearch on model create, update, and delete operations:

```php
// Create new product - automatically indexed
$product = Product::create([
    'name' => 'New Product',
    'sku' => 'PRD-001',
    'price' => 99.99,
]);

// Update - automatically updated in index
$product->update(['price' => 89.99]);

// Delete - automatically removed from index
$product->delete();
```

## Service Information

- **Elasticsearch**: http://localhost:9200
- **Kibana** (Management UI): http://localhost:5601

### Elasticsearch Health Check

```bash
# Check cluster health
curl http://localhost:9200/_cluster/health?pretty

# List all indices
curl http://localhost:9200/_cat/indices?v

# Query a specific index
curl http://localhost:9200/products_index/_search?pretty
```

### Using Kibana

1. Open http://localhost:5601 in your browser
2. Use "Dev Tools" menu to test Elasticsearch queries
3. Manage indices with "Index Management"

## Multi-language Support

Add custom analyzers for proper character handling:

```bash
# Create mapping for products_index with custom analyzer
curl -X PUT "localhost:9200/products_index" -H 'Content-Type: application/json' -d'
{
  "settings": {
    "analysis": {
      "analyzer": {
        "custom_analyzer": {
          "type": "custom",
          "tokenizer": "standard",
          "filter": ["lowercase", "asciifolding"]
        }
      }
    }
  },
  "mappings": {
    "properties": {
      "name": {
        "type": "text",
        "analyzer": "custom_analyzer"
      },
      "description": {
        "type": "text",
        "analyzer": "custom_analyzer"
      }
    }
  }
}
'
```

## Performance Tips

1. **Bulk Import**: Use batch imports for large datasets
2. **Queue Jobs**: Queue indexing operations for better performance
3. **Selective Fields**: Only index fields that need to be searchable
4. **Update Throttling**: Use throttling for frequently updated models

## Troubleshooting

### Elasticsearch Connection Error
```bash
# Check if the container is running
docker compose ps

# View Elasticsearch logs
docker compose logs elasticsearch
```

### Index Creation Error
```bash
# Manually flush and reimport the index
docker compose exec php php artisan scout:flush "App\Models\Product"
docker compose exec php php artisan scout:import "App\Models\Product"
```

## Useful Commands

```bash
# Start all services
docker compose up -d

# Connect to Elasticsearch container
docker compose exec elasticsearch sh

# Connect to PHP container
docker compose exec php sh

# Restart Elasticsearch
docker compose restart elasticsearch
```
