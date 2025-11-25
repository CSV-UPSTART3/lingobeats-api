# **LingoBeats Web API**

Web API that allows user to explore *songs*, fetching *lyrics*, and AI-generated *materials* from level-based *vocabularies*.

## **Routes**
### **Root check**
`GET /`
<br>
Status:
* 200: API server running (happy)

### **Get songs**
#### popular trends
`GET /songs?`
<br>
Status:
* 200: Song list returned (happy)
* 404: Songs not found (sad)
* 500: problems finding data (bad)

#### sesrch with query parameters
`GET /songs?category=...&query=...`
<br>
Status:
* 200: Song list returned (happy)
* 400: Parameters invalid (sad)
* 404: Songs not found (sad)
* 500: problems finding data (bad)

### **Search for a song information**
`GET /songs/{song_id}`
<br>
Status:
* 200: Song information returned (happy)
* 500: problems finding data (bad)

### **Search for a song's lyrics**
`GET /songs/{song_id}/lyrics`
<br>
Status:
* 200: Lyrics returned (happy)
* 422: Lyrics not recommended for English learners (sad)
* 500: problems finding data (bad)

### **Search for a song's level**
`GET /songs/{song_id}/level`
<br>
Status:
* 200: Song level returned (happy)
* 404: Song level not exists (sad)
* 500: problems finding data (bad)

### **Search for a song's material**
`GET /songs/{song_id}/material`
<br>
Status:
* 200: Material returned (happy)
* 404: Song/Material not exists (sad)
* 500: problems finding data (bad)
<br>

`POST /songs/{song_id}/level`
<br>
Status:
* 200: Material returned (happy)
* 500: problems finding or storing data (bad)