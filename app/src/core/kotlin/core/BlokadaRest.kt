package core

import retrofit2.Call
import retrofit2.http.GET

interface BlokadaRestApi {

    @GET("v5/announcement")
    fun getAnnouncement(): Call<BlokadaRestModel.Announcement>
}

object BlokadaRestModel {
    data class Announcement(
            val shouldAnnounce: Boolean,
            val index: Int,
            val id: String,
            val contentUrl: String
    )
}
