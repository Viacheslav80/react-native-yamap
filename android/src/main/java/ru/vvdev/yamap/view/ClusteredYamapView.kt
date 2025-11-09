package ru.vvdev.yamap.view

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Typeface
import android.graphics.Rect

import android.graphics.Path

import android.view.View
import com.yandex.mapkit.geometry.Point
import com.yandex.mapkit.map.Cluster
import com.yandex.mapkit.map.ClusterListener
import com.yandex.mapkit.map.ClusterTapListener
import com.yandex.mapkit.map.IconStyle
import com.yandex.mapkit.map.PlacemarkMapObject
import com.yandex.runtime.image.ImageProvider
import kotlin.math.abs
import kotlin.math.sqrt

class ClusteredYamapView(context: Context?) : YamapView(context), ClusterListener,
    ClusterTapListener {
    private val clusterCollection = mapWindow.map.mapObjects.addClusterizedPlacemarkCollection(this)
    private var clusterColor = 0
    private val placemarksMap: HashMap<String?, PlacemarkMapObject?> = HashMap<String?, PlacemarkMapObject?>()
    private var pointsList = ArrayList<Point>()

private inner class HiveClusterImageProvider(private val text: String) : ImageProvider() {
    override fun getId(): String {
        return "hive_cluster_$text"
    }

    override fun getImage(): Bitmap {
        // Размеры как в SVG (71x78) с масштабированием
        val width = (71 * 3.0).toInt()  // 99px
        val height = (78 * 3.0).toInt() // 109px

        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        val paint = Paint().apply {
            isAntiAlias = true
        }

        // Основной белый шестиугольник (внешний)
        val outerHexagon = Path().apply {
            moveTo(39.5673f * 3.0f, 1.06982f * 3.0f)
            lineTo(31.4327f * 3.0f, 1.0696f * 3.0f)
            lineTo(4.06851f * 3.0f, 16.5748f * 3.0f)
            lineTo(0f, 23.4905f * 3.0f)
            lineTo(0f, 54.5072f * 3.0f)
            lineTo(4.0673f * 3.0f, 61.4225f * 3.0f)
            lineTo(31.4327f * 3.0f, 76.9302f * 3.0f)
            lineTo(39.5673f * 3.0f, 76.9302f * 3.0f)
            lineTo(66.9327f * 3.0f, 61.4225f * 3.0f)
            lineTo(71f * 3.0f, 54.5072f * 3.0f)
            lineTo(71f * 3.0f, 23.4926f * 3.0f)
            lineTo(66.9327f * 3.0f, 16.5772f * 3.0f)
            close()
        }

        // Заливаем белым
        paint.color = Color.WHITE
        paint.style = Paint.Style.FILL
        canvas.drawPath(outerHexagon, paint)

        // Внутренний шестиугольник с обводкой
        val innerHexagon = Path().apply {
            moveTo(32.8515f * 3.0f, 12.5576f * 3.0f)
            lineTo(37.3164f * 3.0f, 12.5576f * 3.0f)
            lineTo(57.3056f * 3.0f, 23.8604f * 3.0f)
            lineTo(59.5156f * 3.0f, 27.5957f * 3.0f)
            lineTo(59.5156f * 3.0f, 50.2012f * 3.0f)
            lineTo(57.3056f * 3.0f, 53.9355f * 3.0f)
            lineTo(37.3164f * 3.0f, 65.2383f * 3.0f)
            lineTo(33.1133f * 3.0f, 65.376f * 3.0f)
            lineTo(32.8515f * 3.0f, 65.2383f * 3.0f)
            lineTo(12.8613f * 3.0f, 53.9355f * 3.0f)
            lineTo(10.6523f * 3.0f, 50.2012f * 3.0f)
            lineTo(10.6523f * 3.0f, 27.5938f * 3.0f)
            lineTo(12.8623f * 3.0f, 23.8594f * 3.0f)
            close()
        }

        // Оранжевая обводка (#FF4F12)
        val orangeColor = Color.parseColor("#FF4F12")
        paint.color = orangeColor
        paint.style = Paint.Style.STROKE
        paint.strokeWidth = 7.5f // 3.0 * 1.4
        canvas.drawPath(innerHexagon, paint)

        // Рисуем текст
        paint.style = Paint.Style.FILL
        paint.textSize = 55.0f // 22 * 1.4
        paint.typeface = Typeface.create(Typeface.DEFAULT, Typeface.NORMAL)
        paint.color = orangeColor

        // Добавляем белую обводку вокруг текста
        paint.style = Paint.Style.FILL_AND_STROKE
        paint.strokeWidth = 4.0f // 2.0 * 1.4
        paint.setShadowLayer(2f, 0f, 0f, Color.WHITE)

        // Центрируем текст
        val textBounds = Rect()
        paint.getTextBounds(text, 0, text.length, textBounds)
        val x = (width - textBounds.width()) / 2.1f
        val y = (height + textBounds.height()) / 2f - textBounds.bottom

        canvas.drawText(text, x, y, paint)

        return bitmap
    }
}

    fun setClusteredMarkers(points: ArrayList<Any>) {
        clusterCollection.clear()
        placemarksMap.clear()
        val pt = ArrayList<Point>()
        for (i in points.indices) {
            val point = points[i] as HashMap<String, Double>
            pt.add(Point(point["lat"]!!, point["lon"]!!))
        }
        val placemarks = clusterCollection.addPlacemarks(pt, HiveClusterImageProvider(points.size.toString()), IconStyle())
        pointsList = pt
        for (i in placemarks.indices) {
            val placemark = placemarks[i]
            placemarksMap["" + placemark.geometry.latitude + placemark.geometry.longitude] =
                placemark
            val child: Any? = getChildAt(i)
            if (child != null && child is YamapMarker) {
                child.setMarkerMapObject(placemark)
            }
        }
        clusterCollection.clusterPlacemarks(50.0, 12)
    }

    fun setClustersColor(color: Int) {
        clusterColor = color
        updateUserMarkersColor()
    }

    private fun updateUserMarkersColor() {
        clusterCollection.clear()
        val placemarks = clusterCollection.addPlacemarks(
            pointsList,
            HiveClusterImageProvider(pointsList.size.toString()),
            IconStyle()
        )
        for (i in placemarks.indices) {
            val placemark = placemarks[i]
            placemarksMap["" + placemark.geometry.latitude + placemark.geometry.longitude] =
                placemark
            val child: Any? = getChildAt(i)
            if (child != null && child is YamapMarker) {
                child.setMarkerMapObject(placemark)
            }
        }
        clusterCollection.clusterPlacemarks(50.0, 12)
    }

    /*override fun addFeature(child: View?, index: Int) {
        val marker = child as YamapMarker?
        val placemark = placemarksMap["" + marker!!.point!!.latitude + marker.point!!.longitude]
        if (placemark != null) {
            marker.setMarkerMapObject(placemark)
        } else if (child is YamapCircle) {
            val _child = child
            val obj = mapWindow.map.mapObjects.addCircle(_child.circle)
            _child.setCircleMapObject(obj)
        }
    }

    override fun removeChild(index: Int) {
        if (getChildAt(index) is YamapMarker) {
            val child = getChildAt(index) as YamapMarker ?: return
            val mapObject = child.rnMapObject
            if (mapObject == null || !mapObject.isValid) return
            clusterCollection.remove(mapObject)
            placemarksMap.remove("" + child.point!!.latitude + child.point!!.longitude)
        }
    }*/

    override fun addFeature(child: View?, index: Int) {
        when (child) {
            is YamapMarker -> {
                val point = child.point ?: return
                val key = "${point.latitude}${point.longitude}"
                val placemark = placemarksMap[key]
                if (placemark != null) {
                    child.setMarkerMapObject(placemark)
                }
            }

            is YamapCircle -> {
                // Используем публичную переменную circle
                val circleMapObject = mapWindow.map.mapObjects.addCircle(child.circle)
                child.setCircleMapObject(circleMapObject)
            }

            is YamapPolygon -> {
                // Аналогично — polygon должен быть публичным
                val polygonMapObject = mapWindow.map.mapObjects.addPolygon(child.polygon)
                child.setPolygonMapObject(polygonMapObject)
            }

            is YamapPolyline -> {
                val polylineMapObject = mapWindow.map.mapObjects.addPolyline(child.polyline)
                child.setPolylineMapObject(polylineMapObject)
            }

            else -> super.addFeature(child, index)
        }
    }

    override fun removeChild(index: Int) {
        val child = getChildAt(index) ?: return

        when (child) {
            is YamapMarker -> {
                val mapObject = child.rnMapObject
                if (mapObject != null && mapObject.isValid) {
                    clusterCollection.remove(mapObject)
                    placemarksMap.remove("${child.point!!.latitude}${child.point!!.longitude}")
                }
            }

            is YamapCircle,
            is YamapPolygon,
            is YamapPolyline -> {
                val mapObject = child.rnMapObject
                if (mapObject != null && mapObject.isValid) {
                    mapWindow.map.mapObjects.remove(mapObject)
                }
            }

            else -> super.removeChild(index)
        }
    }

    override fun onClusterAdded(cluster: Cluster) {
        cluster.appearance.setIcon(HiveClusterImageProvider(cluster.size.toString()))
        cluster.addClusterTapListener(this)
    }

    override fun onClusterTap(cluster: Cluster): Boolean {
        val points = ArrayList<Point?>()
        for (placemark in cluster.placemarks) {
            points.add(placemark.geometry)
        }
        fitMarkers(points)
        return true
    }

    private inner class TextImageProvider(private val text: String) : ImageProvider() {
        override fun getId(): String {
            return "text_$text"
        }

        override fun getImage(): Bitmap {
            val textPaint = Paint()
            textPaint.textSize = Companion.FONT_SIZE
            textPaint.textAlign = Paint.Align.CENTER
            textPaint.style = Paint.Style.FILL
            textPaint.isAntiAlias = true

            val widthF = textPaint.measureText(text)
            val textMetrics = textPaint.fontMetrics
            val heightF =
                (abs(textMetrics.bottom.toDouble()) + abs(textMetrics.top.toDouble())).toFloat()
            val textRadius = sqrt((widthF * widthF + heightF * heightF).toDouble())
                .toFloat() / 2
            val internalRadius = textRadius + Companion.MARGIN_SIZE
            val externalRadius = internalRadius + Companion.STROKE_SIZE

            val width = (2 * externalRadius + 0.5).toInt()

            val bitmap = Bitmap.createBitmap(width, width, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(bitmap)

            val backgroundPaint = Paint()
            backgroundPaint.isAntiAlias = true
            backgroundPaint.color = clusterColor
            canvas.drawCircle(
                (width / 2).toFloat(),
                (width / 2).toFloat(),
                externalRadius,
                backgroundPaint
            )

            backgroundPaint.color = Color.WHITE
            canvas.drawCircle(
                (width / 2).toFloat(),
                (width / 2).toFloat(),
                internalRadius,
                backgroundPaint
            )

            canvas.drawText(
                text,
                (width / 2).toFloat(),
                width / 2 - (textMetrics.ascent + textMetrics.descent) / 2,
                textPaint
            )

            return bitmap
        }
    }
    companion object {
        private const val FONT_SIZE = 45f
        private const val MARGIN_SIZE = 9f
        private const val STROKE_SIZE = 9f
    }
}
